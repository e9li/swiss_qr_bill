defmodule SwissQrBill.Output.SvgOutput do
  @moduledoc """
  Generates SVG output by converting the PDF via pdftocairo.
  All text is automatically converted to glyph outlines (paths),
  ensuring pixel-perfect rendering on all devices without font dependencies.

  Requires `pdftocairo` (from poppler-utils) to be installed.
  - macOS: `brew install poppler`
  - Ubuntu/Debian: `apt install poppler-utils`
  """

  alias SwissQrBill.Output.PdfOutput

  # Bound the external conversion so a hung pdftocairo cannot block the caller
  # indefinitely.
  @conversion_timeout 30_000

  @doc false
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(bill, opts \\ []) do
    with {:ok, pdf_binary} <- PdfOutput.render(bill, opts) do
      pdf_to_svg(pdf_binary)
    end
  end

  defp pdf_to_svg(pdf_binary) do
    # Private per-call directory: the intermediate PDF contains payment data
    # and must not be readable by other local users while it exists.
    dir = Path.join(System.tmp_dir!(), "qrbill_#{:erlang.unique_integer([:positive])}")
    tmp_pdf = Path.join(dir, "qrbill.pdf")
    tmp_svg = Path.join(dir, "qrbill.svg")

    try do
      File.mkdir_p!(dir)
      File.chmod!(dir, 0o700)
      File.write!(tmp_pdf, pdf_binary)

      case run_pdftocairo(["-svg", tmp_pdf, tmp_svg]) do
        :ok -> {:ok, File.read!(tmp_svg)}
        {:error, reason} -> {:error, "pdftocairo SVG conversion failed: #{reason}"}
      end
    after
      File.rm_rf(dir)
    end
  end

  defp run_pdftocairo(args) do
    task =
      Task.async(fn ->
        try do
          System.cmd("pdftocairo", args, stderr_to_stdout: true)
        rescue
          e in ErlangError ->
            case e do
              %ErlangError{original: :enoent} -> :pdftocairo_missing
              _ -> reraise e, __STACKTRACE__
            end
        end
      end)

    case Task.yield(task, @conversion_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {_, 0}} -> :ok
      {:ok, :pdftocairo_missing} -> {:error, "pdftocairo not found — install poppler-utils"}
      {:ok, {output, _code}} -> {:error, output}
      nil -> {:error, "timed out after #{@conversion_timeout}ms"}
      {:exit, reason} -> {:error, inspect(reason)}
    end
  end
end
