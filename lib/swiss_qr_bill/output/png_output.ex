defmodule SwissQrBill.Output.PngOutput do
  @moduledoc """
  Generates PNG output by rasterizing the PDF via pdftocairo.
  The PDF is the source of truth — PNG is a pixel-perfect rasterization.

  Requires `pdftocairo` (from poppler-utils) to be installed.
  - macOS: `brew install poppler`
  - Ubuntu/Debian: `apt install poppler-utils`
  """

  alias SwissQrBill.Output.PdfOutput

  # Bound the external conversion so a hung pdftocairo cannot block the caller
  # indefinitely.
  @conversion_timeout 30_000

  # Sane raster resolution bounds — an unbounded dpi is handed to pdftocairo
  # as-is and can make poppler allocate an OOM-scale bitmap.
  @dpi_range 36..2400

  @doc false
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(bill, opts \\ []) do
    dpi = Keyword.get(opts, :dpi, 300)

    with :ok <- validate_dpi(dpi),
         {:ok, pdf_binary} <- PdfOutput.render(bill, opts) do
      pdf_to_png(pdf_binary, dpi)
    end
  end

  defp validate_dpi(dpi) when is_integer(dpi) and dpi in @dpi_range, do: :ok

  defp validate_dpi(dpi) do
    {:error,
     "dpi must be an integer between #{@dpi_range.first} and #{@dpi_range.last}, " <>
       "got: #{inspect(dpi)}"}
  end

  defp pdf_to_png(pdf_binary, dpi) do
    # Private per-call directory: the intermediate PDF contains payment data
    # and must not be readable by other local users while it exists.
    dir = Path.join(System.tmp_dir!(), "qrbill_#{:erlang.unique_integer([:positive])}")
    tmp_pdf = Path.join(dir, "qrbill.pdf")
    # pdftocairo -png -singlefile appends .png to the output base name
    tmp_base = Path.join(dir, "qrbill")
    tmp_png = tmp_base <> ".png"

    try do
      File.mkdir_p!(dir)
      File.chmod!(dir, 0o700)
      File.write!(tmp_pdf, pdf_binary)

      case run_pdftocairo(["-png", "-r", to_string(dpi), "-singlefile", tmp_pdf, tmp_base]) do
        :ok -> {:ok, File.read!(tmp_png)}
        {:error, reason} -> {:error, "pdftocairo PNG conversion failed: #{reason}"}
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
