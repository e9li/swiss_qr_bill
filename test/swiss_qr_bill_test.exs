defmodule SwissQrBillTest do
  use ExUnit.Case

  alias SwissQrBill.Address

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

  describe "validation" do
    test "valid full bill passes validation" do
      assert {:ok, _bill} = SwissQrBill.validate(sample_bill())
    end

    test "valid minimal bill passes validation" do
      assert {:ok, _bill} = SwissQrBill.validate(minimal_bill())
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
  end
end
