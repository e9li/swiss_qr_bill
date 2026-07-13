defmodule SwissQrBillTest do
  use ExUnit.Case

  alias SwissQrBill.{Address, Validation}

  defp sample_bill do
    creditor = Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
    debtor = Address.new("Max Muster", "Hauptstrasse", "42", "3000", "Bern", "CH")

    {:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")

    SwissQrBill.new()
    |> SwissQrBill.set_creditor(creditor)
    |> SwissQrBill.set_creditor_information("CH44 3199 9123 0008 8901 2")
    |> SwissQrBill.set_payment_amount("CHF", 2500.25)
    |> SwissQrBill.set_debtor(debtor)
    |> SwissQrBill.set_payment_reference(:qrr, ref)
    |> SwissQrBill.set_additional_information("Invoice 2024-001")
  end

  defp minimal_bill do
    creditor = Address.new("Muster AG", "8001", "Zürich", "CH")

    SwissQrBill.new()
    |> SwissQrBill.set_creditor(creditor)
    |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
    |> SwissQrBill.set_payment_amount("CHF")
    |> SwissQrBill.set_payment_reference(:non)
  end

  defp scor_bill do
    creditor = Address.new("Example Ltd", "Rue du Lac", "5", "1200", "Genève", "CH")
    {:ok, ref} = SwissQrBill.Reference.CreditorReferenceGenerator.generate("I20200631")

    SwissQrBill.new()
    |> SwissQrBill.set_creditor(creditor)
    |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
    |> SwissQrBill.set_payment_amount("EUR", 199.95)
    |> SwissQrBill.set_payment_reference(:scor, ref)
  end

  defp eur_qr_iban_bill do
    creditor = Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
    {:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")

    SwissQrBill.new()
    |> SwissQrBill.set_creditor(creditor)
    |> SwissQrBill.set_creditor_information("CH44 3199 9123 0008 8901 2")
    |> SwissQrBill.set_payment_amount("EUR", 100.0)
    |> SwissQrBill.set_payment_reference(:qrr, ref)
  end

  describe "new/0" do
    test "creates empty bill" do
      bill = SwissQrBill.new()
      assert bill.creditor == nil
      assert bill.creditor_information == nil
      assert bill.payment_amount == nil
      assert bill.debtor == nil
      assert bill.payment_reference == nil
      assert bill.additional_information == nil
      assert bill.alternative_schemes == []
    end
  end

  describe "builder functions" do
    test "set_creditor/2 sets creditor address" do
      bill =
        SwissQrBill.new() |> SwissQrBill.set_creditor(Address.new("Test", "8000", "Zürich", "CH"))

      assert bill.creditor.name == "Test"
    end

    test "set_creditor_information/2 with string IBAN" do
      bill =
        SwissQrBill.new() |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")

      assert bill.creditor_information.iban == "CH9300762011623852957"
    end

    test "set_creditor_information/2 with CreditorInformation struct" do
      ci = SwissQrBill.CreditorInformation.new("CH93 0076 2011 6238 5295 7")
      bill = SwissQrBill.new() |> SwissQrBill.set_creditor_information(ci)
      assert bill.creditor_information.iban == "CH9300762011623852957"
    end

    test "set_payment_amount/2 with currency only" do
      bill = SwissQrBill.new() |> SwissQrBill.set_payment_amount("CHF")
      assert bill.payment_amount.currency == "CHF"
      assert bill.payment_amount.amount == nil
    end

    test "set_payment_amount/3 with currency and amount" do
      bill = SwissQrBill.new() |> SwissQrBill.set_payment_amount("EUR", 100.50)
      assert bill.payment_amount.currency == "EUR"
      assert Decimal.equal?(bill.payment_amount.amount, Decimal.new("100.50"))
    end

    test "set_debtor/2 sets debtor address" do
      bill =
        SwissQrBill.new() |> SwissQrBill.set_debtor(Address.new("Debtor", "3000", "Bern", "CH"))

      assert bill.debtor.name == "Debtor"
    end

    test "set_payment_reference/2 with type only (NON)" do
      bill = SwissQrBill.new() |> SwissQrBill.set_payment_reference(:non)
      assert bill.payment_reference.type == :non
      assert bill.payment_reference.reference == nil
    end

    test "set_payment_reference/3 with type and reference" do
      bill = SwissQrBill.new() |> SwissQrBill.set_payment_reference(:scor, "RF15I20200631")
      assert bill.payment_reference.type == :scor
      assert bill.payment_reference.reference == "RF15I20200631"
    end

    test "set_additional_information/2 with message only" do
      bill = SwissQrBill.new() |> SwissQrBill.set_additional_information("Test msg")
      assert bill.additional_information.message == "Test msg"
      assert bill.additional_information.bill_information == nil
    end

    test "set_additional_information/3 with message and bill info" do
      bill = SwissQrBill.new() |> SwissQrBill.set_additional_information("Msg", "//S1/10/123")
      assert bill.additional_information.message == "Msg"
      assert bill.additional_information.bill_information == "//S1/10/123"
    end

    test "add_alternative_scheme/2 adds scheme" do
      bill =
        SwissQrBill.new()
        |> SwissQrBill.add_alternative_scheme("eBill/B/123")
        |> SwissQrBill.add_alternative_scheme("//S1/10/456")

      assert length(bill.alternative_schemes) == 2
      assert hd(bill.alternative_schemes).parameter == "eBill/B/123"
    end
  end

  describe "validation" do
    test "valid full bill passes validation" do
      assert {:ok, _bill} = SwissQrBill.validate(sample_bill())
    end

    test "valid minimal bill passes validation" do
      assert {:ok, _bill} = SwissQrBill.validate(minimal_bill())
    end

    test "valid SCOR bill passes validation" do
      assert {:ok, _bill} = SwissQrBill.validate(scor_bill())
    end

    test "missing creditor fails" do
      bill = %{sample_bill() | creditor: nil}
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "creditor address"))
    end

    test "missing creditor information fails" do
      bill = %{sample_bill() | creditor_information: nil}
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "creditor_information"))
    end

    test "invalid currency fails" do
      bill = SwissQrBill.set_payment_amount(sample_bill(), "USD", 100.0)
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "currency"))
    end

    test "QR-IBAN with SCOR reference fails" do
      bill = SwissQrBill.set_payment_reference(sample_bill(), :scor, "RF15I20200631")
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "QR-IBAN"))
    end

    test "regular IBAN with QRR reference fails" do
      {:ok, ref} =
        SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")

      bill =
        SwissQrBill.new()
        |> SwissQrBill.set_creditor(Address.new("Test", "8000", "Zürich", "CH"))
        |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
        |> SwissQrBill.set_payment_amount("CHF", 100.0)
        |> SwissQrBill.set_payment_reference(:qrr, ref)

      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "QRR reference type requires QR-IBAN"))
    end

    test "amount too large fails" do
      bill = SwissQrBill.set_payment_amount(sample_bill(), "CHF", 1_000_000_000.00)
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "amount"))
    end

    test "negative amount fails" do
      bill = SwissQrBill.set_payment_amount(sample_bill(), "CHF", -1.0)
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "amount"))
    end

    test "too many alternative schemes fails" do
      bill =
        sample_bill()
        |> SwissQrBill.add_alternative_scheme("one")
        |> SwissQrBill.add_alternative_scheme("two")
        |> SwissQrBill.add_alternative_scheme("three")

      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "alternative"))
    end

    test "bill with alternative schemes validates" do
      bill =
        sample_bill()
        |> SwissQrBill.add_alternative_scheme("eBill/B/123")

      assert {:ok, _} = SwissQrBill.validate(bill)
    end
  end

  describe "v2.4 conformance" do
    test "amount below the 0.01 minimum fails" do
      bill = SwissQrBill.set_payment_amount(sample_bill(), "CHF", 0.0)
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "amount"))
    end

    test "message and bill information exceeding 140 characters combined fails" do
      bill =
        SwissQrBill.set_additional_information(
          sample_bill(),
          String.duplicate("a", 100),
          String.duplicate("b", 50)
        )

      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "together must not exceed 140"))
    end

    test "name with characters outside the QR character set fails" do
      creditor = Address.new("Muster 🎉 AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
      bill = %{sample_bill() | creditor: creditor}
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "not permitted"))
    end

    test "Euro sign in the message is accepted" do
      bill = SwissQrBill.set_additional_information(scor_bill(), "Invoice total €199.95")
      assert {:ok, _} = SwissQrBill.validate(bill)
    end

    test "EUR with QR-IBAN/QRR validates but emits a non-blocking warning" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, _} = SwissQrBill.validate(eur_qr_iban_bill())
        end)

      assert log =~ "only valid for invoices in CHF"
    end

    test "warnings/1 flags EUR + QR-IBAN and is silent for EUR + SCOR" do
      assert [warning] = Validation.warnings(eur_qr_iban_bill())
      assert warning =~ "CHF"
      assert Validation.warnings(scor_bill()) == []
    end
  end

  describe "crash-surface hardening" do
    test "NaN amount string is reported, not raised" do
      bill = SwissQrBill.set_payment_amount(sample_bill(), "CHF", "NaN")
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "amount must be a valid number"))
    end

    test "hand-passed NaN/Infinity Decimals are reported, not raised" do
      for special <- ["NaN", "Infinity", "-Infinity"] do
        bill = %{
          sample_bill()
          | payment_amount: %SwissQrBill.PaymentAmount{
              currency: "CHF",
              amount: Decimal.new(special)
            }
        }

        assert {:error, errors} = SwissQrBill.validate(bill)
        assert Enum.any?(errors, &String.contains?(&1, "amount")), "failed for #{special}"
      end
    end

    test "unknown reference type is rejected at construction" do
      assert_raise FunctionClauseError, fn ->
        SwissQrBill.set_payment_reference(sample_bill(), :cor, "RF15I20200631")
      end
    end

    test "hand-built struct with unknown reference type is reported, not raised" do
      bill = %{
        sample_bill()
        | payment_reference: %SwissQrBill.PaymentReference{type: :cor, reference: "x"}
      }

      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, ":qrr, :scor or :non"))
    end

    test "validate/1 never raises for wrong-typed field contents" do
      base = sample_bill()

      malformed = [
        %{base | creditor: %{name: "not an Address"}},
        %{base | creditor: Map.put(base.creditor, :name, 123)},
        %{base | creditor: Map.put(base.creditor, :postal_code, {:tuple})},
        %{base | creditor: Map.put(base.creditor, :street, :atom)},
        %{base | creditor: Map.put(base.creditor, :country, :CH)},
        %{base | creditor_information: "CH123"},
        %{base | creditor_information: %SwissQrBill.CreditorInformation{iban: 123}},
        %{base | payment_amount: %{currency: "CHF"}},
        %{base | payment_amount: %SwissQrBill.PaymentAmount{currency: :chf, amount: :nan}},
        %{base | payment_reference: "QRR"},
        %{
          base
          | payment_reference: %SwissQrBill.PaymentReference{type: :qrr, reference: 123}
        },
        %{
          base
          | payment_reference: %SwissQrBill.PaymentReference{type: :scor, reference: %{}}
        },
        %{
          base
          | additional_information: %SwissQrBill.AdditionalInformation{
              message: :oops,
              bill_information: %{}
            }
        },
        %{base | alternative_schemes: ["not a struct"]},
        %{base | alternative_schemes: [%SwissQrBill.AlternativeScheme{parameter: 42}]},
        %{base | debtor: %{}}
      ]

      for bill <- malformed do
        assert {:error, errors} = SwissQrBill.validate(bill)
        assert is_list(errors) and errors != []
      end
    end

    test "constructors coerce plausible integer inputs" do
      addr = SwissQrBill.Address.new("Muster AG", 8001, "Zürich", "CH")
      assert addr.postal_code == "8001"

      addr6 = SwissQrBill.Address.new("Muster AG", "Bahnhofstrasse", 1, 8001, "Zürich", "CH")
      assert addr6.building_number == "1"
      assert addr6.postal_code == "8001"

      pr = SwissQrBill.PaymentReference.new(:qrr, 210_000_000_003_139_471_430_009_017)
      assert pr.reference == "210000000003139471430009017"
    end

    test "non-binary currency is reported, not raised" do
      bill = %{sample_bill() | payment_amount: SwissQrBill.PaymentAmount.new(:chf, 10)}
      assert {:error, errors} = SwissQrBill.validate(bill)
      assert Enum.any?(errors, &String.contains?(&1, "currency"))
    end
  end

  describe "PNG dpi bounds" do
    test "rejects out-of-range and non-integer dpi" do
      for dpi <- [0, 35, 2401, 100_000, -300, 30.5, "300"] do
        assert {:error, message} = SwissQrBill.to_png(sample_bill(), dpi: dpi)
        assert message =~ "dpi", "expected dpi error for #{inspect(dpi)}"
      end
    end
  end

  describe "PDF output" do
    test "generates PDF for full bill" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), language: :de)
      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF for minimal bill" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(minimal_bill(), language: :de)
      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF for SCOR bill" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(scor_bill(), language: :fr)
      assert is_binary(pdf)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF in all languages" do
      for lang <- [:de, :fr, :it, :en, :rm] do
        assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), language: lang)
        assert is_binary(pdf), "Failed for language: #{lang}"
        assert String.starts_with?(pdf, "%PDF"), "Not a PDF for language: #{lang}"
      end
    end

    test "generates PDF with output_size :payment_slip" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), output_size: :payment_slip)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF with output_size :a4" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), output_size: :a4)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF with output_size :qr_code" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill(), output_size: :qr_code)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF with bill information" do
      bill = SwissQrBill.set_additional_information(sample_bill(), "Test", "//S1/10/2024001")
      assert {:ok, pdf} = SwissQrBill.to_pdf(bill)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "generates PDF with alternative schemes" do
      bill =
        sample_bill()
        |> SwissQrBill.add_alternative_scheme("eBill/B/41010560425610173")
        |> SwissQrBill.add_alternative_scheme("//S1/10/10201409/11/190512")

      assert {:ok, pdf} = SwissQrBill.to_pdf(bill)
      assert String.starts_with?(pdf, "%PDF")
    end

    test "returns error for invalid bill" do
      bill = %{sample_bill() | creditor: nil}
      assert {:error, _} = SwissQrBill.to_pdf(bill)
    end

    test "default options generate valid PDF" do
      assert {:ok, pdf} = SwissQrBill.to_pdf(sample_bill())
      assert String.starts_with?(pdf, "%PDF")
    end
  end

  describe "SVG output" do
    test "generates SVG for full bill" do
      assert {:ok, svg} = SwissQrBill.to_svg(sample_bill(), language: :de)
      assert is_binary(svg)
      assert svg =~ "<svg"
      assert svg =~ "</svg>"
    end

    test "generates SVG for minimal bill" do
      assert {:ok, svg} = SwissQrBill.to_svg(minimal_bill())
      assert svg =~ "<svg"
    end

    test "generates SVG for SCOR bill" do
      assert {:ok, svg} = SwissQrBill.to_svg(scor_bill(), language: :fr)
      assert svg =~ "<svg"
    end

    test "generates SVG in all languages" do
      for lang <- [:de, :fr, :it, :en, :rm] do
        assert {:ok, svg} = SwissQrBill.to_svg(sample_bill(), language: lang)
        assert svg =~ "<svg", "Failed for language: #{lang}"
      end
    end

    test "generates SVG with output_size :payment_slip" do
      assert {:ok, svg} = SwissQrBill.to_svg(sample_bill(), output_size: :payment_slip)
      assert svg =~ "<svg"
    end

    test "generates SVG with output_size :a4" do
      assert {:ok, svg} = SwissQrBill.to_svg(sample_bill(), output_size: :a4)
      assert svg =~ "<svg"
    end

    test "generates SVG with output_size :qr_code" do
      assert {:ok, svg} = SwissQrBill.to_svg(sample_bill(), output_size: :qr_code)
      assert svg =~ "<svg"
    end

    test "returns error for invalid bill" do
      bill = %{sample_bill() | creditor: nil}
      assert {:error, _} = SwissQrBill.to_svg(bill)
    end

    test "SVG contains path elements (text converted to paths)" do
      assert {:ok, svg} = SwissQrBill.to_svg(sample_bill())
      # pdftocairo converts text to <path> elements
      assert svg =~ "<path"
    end
  end

  describe "PNG output" do
    test "generates PNG for full bill" do
      assert {:ok, png} = SwissQrBill.to_png(sample_bill(), language: :de)
      assert is_binary(png)
      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "generates PNG for minimal bill" do
      assert {:ok, png} = SwissQrBill.to_png(minimal_bill())
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "generates PNG for SCOR bill" do
      assert {:ok, png} = SwissQrBill.to_png(scor_bill(), language: :it)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "generates PNG in all languages" do
      for lang <- [:de, :fr, :it, :en, :rm] do
        assert {:ok, png} = SwissQrBill.to_png(sample_bill(), language: lang)
        assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
      end
    end

    test "generates PNG with output_size :payment_slip" do
      assert {:ok, png} = SwissQrBill.to_png(sample_bill(), output_size: :payment_slip)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "generates PNG with output_size :a4" do
      assert {:ok, png} = SwissQrBill.to_png(sample_bill(), output_size: :a4)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "generates PNG with output_size :qr_code" do
      assert {:ok, png} = SwissQrBill.to_png(sample_bill(), output_size: :qr_code)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "generates PNG with custom DPI" do
      assert {:ok, png_72} = SwissQrBill.to_png(sample_bill(), dpi: 72)
      assert {:ok, png_300} = SwissQrBill.to_png(sample_bill(), dpi: 300)
      # Higher DPI should produce a larger file
      assert byte_size(png_300) > byte_size(png_72)
    end

    test "returns error for invalid bill" do
      bill = %{sample_bill() | creditor: nil}
      assert {:error, _} = SwissQrBill.to_png(bill)
    end
  end
end
