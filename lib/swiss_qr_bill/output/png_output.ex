defmodule SwissQrBill.Output.PngOutput do
  @moduledoc """
  Generates PNG output by rasterizing the PDF via pdftocairo.
  The PDF is the source of truth — PNG is a pixel-perfect rasterization.

  Requires `pdftocairo` (from poppler-utils) to be installed.
  - macOS: `brew install poppler`
  - Ubuntu/Debian: `apt install poppler-utils`
  """

  alias SwissQrBill.Output.PdfOutput

  @doc """
  Generates the payment part as a PNG binary.
  Uses PdfOutput as source and rasterizes via pdftocairo.

  ## Options
  - `:language` — `:de`, `:fr`, `:it`, `:en`, or `:rm` (default: `:de`)
  - `:dpi` — resolution in DPI (default: 300)
  """
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(bill, opts \\ []) do
    with {:ok, pdf_binary} <- PdfOutput.render(bill, opts) do
      dpi = Keyword.get(opts, :dpi, 300)
      pdf_to_png(pdf_binary, dpi)
    end
  end

  defp pdf_to_png(pdf_binary, dpi) do
    tmp_pdf = System.tmp_dir!() |> Path.join("qrbill_#{:erlang.unique_integer([:positive])}.pdf")
    # pdftocairo -png -singlefile appends .png to the output base name
    tmp_base = String.replace_suffix(tmp_pdf, ".pdf", "")
    tmp_png = tmp_base <> ".png"

    try do
      File.write!(tmp_pdf, pdf_binary)

      args = ["-png", "-r", to_string(dpi), "-singlefile", tmp_pdf, tmp_base]

      case System.cmd("pdftocairo", args, stderr_to_stdout: true) do
        {_, 0} ->
          png = File.read!(tmp_png)
          {:ok, png}

        {error, _code} ->
          {:error, "pdftocairo PNG conversion failed: #{error}"}
      end
    after
      File.rm(tmp_pdf)
      File.rm(tmp_png)
    end
  end
end
