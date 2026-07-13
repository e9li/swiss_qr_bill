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

    test "soft-broken tokens never leak a raw 0x0B byte into the content stream" do
      # Regression: ZWSP-based soft breaks were byte-truncated by the pdf
      # library's WinAnsi table to vertical-tab (an undefined glyph).
      assert {:ok, pdf} = SwissQrBill.to_pdf(long_bill(company: @compound))
      refute pdf_text(pdf) =~ <<0x0B>>
    end
  end

  describe "soft_break/1" do
    @shy <<0xAD::utf8>>

    test "leaves normal, fitting text untouched" do
      assert PdfOutput.soft_break("Muster AG Bahnhofstrasse 1") == "Muster AG Bahnhofstrasse 1"
    end

    test "inserts a lossless soft-hyphen break into over-long tokens" do
      out = PdfOutput.soft_break(@compound)

      assert String.contains?(out, @shy)
      # Removing the inserted soft hyphens restores the original exactly.
      assert String.replace(out, @shy, "") == @compound

      # Every break-free chunk now fits the max token length.
      for chunk <- out |> String.split(@shy) |> Enum.flat_map(&String.split(&1, " ")) do
        assert String.length(chunk) <= 22
      end
    end
  end

  describe "v2.4 output conformance" do
    test ":a4 renders the 'Separate before paying in' note above the slip" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(long_bill(), output_size: :a4, language: :de)
      assert pdf_text(pdf) =~ "Vor der Einzahlung abzutrennen"

      assert {:ok, en} = SwissQrBill.to_pdf(long_bill(), output_size: :a4, language: :en)
      assert pdf_text(en) =~ "Separate before paying in"
    end

    test ":payment_slip does not carry the note (perforated paper case)" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(long_bill(), output_size: :payment_slip)
      refute pdf_text(pdf) =~ "Vor der Einzahlung abzutrennen"
    end

    test "a payload exceeding QR version 25 is rejected, not silently oversized" do
      # Diacritic-heavy fields are 2 bytes each in UTF-8: a max-length bill
      # exceeds version-25-M byte capacity (1273) while every field is within
      # its character limit, so validation passes and the QR layer must reject.
      umlauts = fn n -> String.duplicate("ä", n) end

      bill =
        SwissQrBill.new()
        |> SwissQrBill.set_creditor(
          SwissQrBill.Address.new(umlauts.(70), umlauts.(70), "1", "8001", umlauts.(35), "CH")
        )
        |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
        |> SwissQrBill.set_payment_amount("CHF", 100.0)
        |> SwissQrBill.set_debtor(
          SwissQrBill.Address.new(umlauts.(70), umlauts.(70), "2", "3000", umlauts.(35), "CH")
        )
        |> SwissQrBill.set_payment_reference(:non)
        |> SwissQrBill.set_additional_information(umlauts.(140))
        |> SwissQrBill.add_alternative_scheme("eBill/B/" <> umlauts.(90))
        |> SwissQrBill.add_alternative_scheme("//S1/10/" <> umlauts.(90))

      assert {:ok, _} = SwissQrBill.validate(bill)
      assert {:error, message} = SwissQrBill.to_pdf(bill)
      assert message =~ "QR payload too large"
    end
  end

  describe "sanitize_text/1 (WinAnsi transliteration)" do
    test "keeps WinAnsi-encodable characters untouched" do
      assert PdfOutput.sanitize_text("Müller & Cie, Genève — 100 € (Šariš)") ==
               "Müller & Cie, Genève — 100 € (Šariš)"
    end

    test "strips diacritics from decomposable Latin Extended-A letters" do
      assert PdfOutput.sanitize_text("Ștefan Țară") == "Stefan Tara"
      assert PdfOutput.sanitize_text("Āīū ĂĔĞ Ąą") == "Aiu AEG Aa"
    end

    test "maps non-decomposable letters explicitly" do
      assert PdfOutput.sanitize_text("Łukasz Ĳsselmeer đŧħ") == "Lukasz IJsselmeer dth"
    end

    test "doubles backslashes so PDF string literals stay intact" do
      assert PdfOutput.sanitize_text("ACME\\") == "ACME\\\\"

      # End-to-end: a validated name ending in a backslash must not corrupt
      # the content stream — the PDF still renders and parses.
      creditor = SwissQrBill.Address.new("ACME\\ AG", "8001", "Zürich", "CH")

      bill =
        SwissQrBill.new()
        |> SwissQrBill.set_creditor(creditor)
        |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
        |> SwissQrBill.set_payment_amount("CHF", 100.0)
        |> SwissQrBill.set_payment_reference(:non)

      assert {:ok, pdf} = SwissQrBill.to_pdf(bill)
      assert pdf_text(pdf) =~ "ACME\\\\ AG"
    end

    test "bills with Romanian and Polish names render in all formats" do
      creditor = SwissQrBill.Address.new("Ștefan Țară AG", "8001", "Zürich", "CH")
      debtor = SwissQrBill.Address.new("Łukasz Ĳsselmeer", "3000", "Bern", "CH")

      bill =
        SwissQrBill.new()
        |> SwissQrBill.set_creditor(creditor)
        |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
        |> SwissQrBill.set_payment_amount("CHF", 100.0)
        |> SwissQrBill.set_debtor(debtor)
        |> SwissQrBill.set_payment_reference(:non)

      # Validation accepts the full §4.1.1 charset...
      assert {:ok, _} = SwissQrBill.validate(bill)
      # ...rendering transliterates instead of crashing...
      assert {:ok, pdf} = SwissQrBill.to_pdf(bill)
      text = pdf_text(pdf)
      assert text =~ "Stefan Tara AG"
      assert text =~ "Lukasz IJsselmeer"
      # ...and the QR payload keeps the ORIGINAL characters.
      payload = SwissQrBill.QrCodeData.encode(bill)
      assert payload =~ "Ștefan Țară AG"
      assert payload =~ "Łukasz Ĳsselmeer"
    end
  end
end
