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

  @doc """
  Generates the payment part as an SVG binary string.
  Uses PdfOutput as source and converts via pdftocairo.

  ## Options
  Same as `PdfOutput.render/2`:
  - `:language` — `:de`, `:fr`, `:it`, `:en`, or `:rm` (default: `:de`)
  """
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(bill, opts \\ []) do
    with {:ok, pdf_binary} <- PdfOutput.render(bill, opts) do
      pdf_to_svg(pdf_binary)
    end
  end

  defp pdf_to_svg(pdf_binary) do
    tmp_pdf = System.tmp_dir!() |> Path.join("qrbill_#{:erlang.unique_integer([:positive])}.pdf")
    tmp_svg = String.replace_suffix(tmp_pdf, ".pdf", ".svg")

    try do
      File.write!(tmp_pdf, pdf_binary)

      case System.cmd("pdftocairo", ["-svg", tmp_pdf, tmp_svg], stderr_to_stdout: true) do
        {_, 0} ->
          svg = File.read!(tmp_svg)
          {:ok, svg}

        {error, _code} ->
          {:error, "pdftocairo SVG conversion failed: #{error}"}
      end
    after
      File.rm(tmp_pdf)
      File.rm(tmp_svg)
    end
  end
end
