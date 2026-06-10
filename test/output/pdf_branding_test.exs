defmodule SwissQrBill.Output.PdfBrandingTest do
  use ExUnit.Case, async: true

  defp sample_bill do
    SwissQrBill.new()
    |> SwissQrBill.set_creditor(
      SwissQrBill.Address.new("Test AG", "Teststrasse", "1", "8000", "Zürich", "CH")
    )
    |> SwissQrBill.set_creditor_information("CH4431999123000889012")
    |> SwissQrBill.set_payment_amount("CHF", 100.0)
    |> SwissQrBill.set_payment_reference(:qrr, "210000000003139471430009017")
  end

  # PDF content streams are FlateDecode-compressed; inflate them so text
  # operators like `(Erstellt mit qrbill.dev) Tj` become assertable.
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

  defp media_box(pdf_binary) do
    [box] = Regex.run(~r/MediaBox \[[^\]]*\]/, pdf_binary)
    box
  end

  describe "branding option" do
    test "is off by default" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill())
      refute pdf_text(pdf) =~ "qrbill.dev"
    end

    test "branding: false renders no branding" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), branding: false)
      refute pdf_text(pdf) =~ "qrbill.dev"
    end

    test "renders localized text for the bill language" do
      assert {:ok, de} = SwissQrBill.to_pdf(sample_bill(), language: :de, branding: true)
      assert pdf_text(de) =~ "Erstellt mit qrbill.dev"

      assert {:ok, en} = SwissQrBill.to_pdf(sample_bill(), language: :en, branding: true)
      assert pdf_text(en) =~ "Created by qrbill.dev"

      # fr/it/rm contain non-ASCII (WinAnsi-encoded) — assert the stable part
      for lang <- [:fr, :it, :rm] do
        assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), language: lang, branding: true)
        assert pdf_text(pdf) =~ "qrbill.dev", "missing branding for #{lang}"
      end
    end

    test "renders for all output sizes" do
      for size <- [:payment_slip, :a4, :qr_code] do
        assert {:ok, pdf} =
                 SwissQrBill.to_pdf(sample_bill(),
                   language: :de,
                   output_size: size,
                   branding: true
                 )

        assert pdf_text(pdf) =~ "Erstellt mit qrbill.dev", "missing branding for #{size}"
      end
    end

    test "qr_code canvas grows by 4mm only when branded" do
      assert {:ok, plain} = SwissQrBill.to_pdf(sample_bill(), output_size: :qr_code)
      assert {:ok, branded} =
               SwissQrBill.to_pdf(sample_bill(), output_size: :qr_code, branding: true)

      assert media_box(plain) == "MediaBox [ 0 0 159 159 ]"
      assert media_box(branded) == "MediaBox [ 0 0 159 170 ]"
    end

    test "payment_slip and a4 page sizes are unchanged by branding" do
      for size <- [:payment_slip, :a4] do
        assert {:ok, plain} = SwissQrBill.to_pdf(sample_bill(), output_size: size)
        assert {:ok, branded} =
                 SwissQrBill.to_pdf(sample_bill(), output_size: size, branding: true)

        assert media_box(plain) == media_box(branded)
      end
    end
  end
end
