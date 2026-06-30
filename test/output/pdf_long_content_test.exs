defmodule SwissQrBill.Output.PdfLongContentTest do
  @moduledoc """
  Long-but-valid (<= spec limits) names/streets/additional info must wrap within
  their column instead of overrunning into the QR code (receipt) or off the page
  edge (payment part). Rendered visual samples for manual comparison are produced
  by `tmp/generate_samples.exs`.
  """
  use ExUnit.Case, async: true

  alias SwissQrBill.Output.PdfOutput

  @qr_iban "CH4431999123000889012"
  @qr_ref "210000000003139471430009017"

  # ASCII-only long words so they can be asserted against the WinAnsi-encoded
  # PDF text stream.
  @long_company "Wohlfahrtsstiftung der Genossenschaft Bergbahnen Engelberg AG"
  @long_street "Untere Bahnhofstrasse beim alten Postareal"
  @long_debtor "Familie Hans-Rudolf Mueller von Habsburg zu Lichtenstein"
  @long_addinfo "Rechnung Nr. 2024-001 fuer Wartungsarbeiten und Servicepauschale Q1"
  # A single 57-char unbreakable token (German compound), no whitespace.
  @compound "Donaudampfschifffahrtsgesellschaftskapitaensmuetzenfabrik AG"

  defp long_bill(opts \\ []) do
    company = Keyword.get(opts, :company, @long_company)

    SwissQrBill.new()
    |> SwissQrBill.set_creditor(
      SwissQrBill.Address.new(company, @long_street, "127b", "6390", "Engelberg", "CH")
    )
    |> SwissQrBill.set_creditor_information(@qr_iban)
    |> SwissQrBill.set_payment_amount("CHF", 2500.25)
    |> SwissQrBill.set_debtor(
      SwissQrBill.Address.new(
        @long_debtor,
        "Obere Industriestrasse hinter dem Gewerbepark",
        "1042",
        "8910",
        "Affoltern am Albis",
        "CH"
      )
    )
    |> SwissQrBill.set_payment_reference(:qrr, @qr_ref)
    |> SwissQrBill.set_additional_information(@long_addinfo)
  end

  # PDF content streams are FlateDecode-compressed; inflate them so text show
  # operators become assertable (same approach as PdfBrandingTest).
  defp pdf_text(pdf_binary) do
    ~r/stream\r?\n(.*?)endstream/s
    |> Regex.scan(pdf_binary, capture: :all_but_first)
    |> Enum.map(fn [chunk] ->
      try do
        z = :zlib.open()
        :ok = :zlib.inflateInit(z)
        out = z |> :zlib.inflate(chunk) |> IO.iodata_to_binary()
        :zlib.close(z)
        out
      catch
        _, _ -> ""
      end
    end)
    |> Enum.join()
  end

  describe "long addresses, company names, and additional info" do
    test "render without error for every output size and language" do
      for size <- [:payment_slip, :a4, :qr_code],
          lang <- [:de, :fr, :it, :en, :rm] do
        assert {:ok, pdf} = SwissQrBill.to_pdf(long_bill(), output_size: size, language: lang),
               "expected success for #{size}/#{lang}"

        assert is_binary(pdf)
      end
    end

    test "wrap without dropping content — every word still appears in the output" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(long_bill(), output_size: :payment_slip)
      text = pdf_text(pdf)

      for word <- ~w(Wohlfahrtsstiftung Genossenschaft Bergbahnen Engelberg
                     Bahnhofstrasse Postareal Wartungsarbeiten Servicepauschale) do
        assert text =~ word, "expected #{inspect(word)} in the rendered output"
      end
    end

    test "a very long unbreakable token (German compound) still renders" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(long_bill(company: @compound))
      assert is_binary(pdf)
      # The first soft-break chunk (<= 22 chars) is rendered contiguously.
      assert pdf_text(pdf) =~ "Donaudampf"
    end
  end

  describe "soft_break/1" do
    @zwsp <<0x200B::utf8>>

    test "leaves normal, fitting text untouched" do
      assert PdfOutput.soft_break("Muster AG Bahnhofstrasse 1") == "Muster AG Bahnhofstrasse 1"
    end

    test "inserts an invisible, lossless break into over-long tokens" do
      out = PdfOutput.soft_break(@compound)

      assert String.contains?(out, @zwsp)
      # Removing the inserted ZWSPs restores the original exactly (lossless).
      assert String.replace(out, @zwsp, "") == @compound

      # Every break-free chunk now fits the max token length.
      for chunk <- out |> String.split(@zwsp) |> Enum.flat_map(&String.split(&1, " ")) do
        assert String.length(chunk) <= 22
      end
    end
  end
end
