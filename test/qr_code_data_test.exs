defmodule SwissQrBill.QrCodeDataTest do
  use ExUnit.Case

  alias SwissQrBill.{Address, QrCodeData}

  test "encodes full bill to spec-compliant payload" do
    creditor = Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
    debtor = Address.new("Max Muster", "Hauptstrasse", "42", "3000", "Bern", "CH")

    {:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")

    bill =
      SwissQrBill.new()
      |> SwissQrBill.set_creditor(creditor)
      |> SwissQrBill.set_creditor_information("CH44 3199 9123 0008 8901 2")
      |> SwissQrBill.set_payment_amount("CHF", 2500.25)
      |> SwissQrBill.set_debtor(debtor)
      |> SwissQrBill.set_payment_reference(:qrr, ref)
      |> SwissQrBill.set_additional_information("Invoice 2024-001")

    payload = QrCodeData.encode(bill)
    lines = String.split(payload, "\r\n")

    # Header
    assert Enum.at(lines, 0) == "SPC"
    assert Enum.at(lines, 1) == "0200"
    assert Enum.at(lines, 2) == "1"

    # Creditor IBAN
    assert Enum.at(lines, 3) == "CH4431999123000889012"

    # Creditor address
    assert Enum.at(lines, 4) == "S"
    assert Enum.at(lines, 5) == "Muster AG"
    assert Enum.at(lines, 6) == "Bahnhofstrasse"
    assert Enum.at(lines, 7) == "1"
    assert Enum.at(lines, 8) == "8001"
    assert Enum.at(lines, 9) == "Zürich"
    assert Enum.at(lines, 10) == "CH"

    # Ultimate creditor (empty placeholder - 7 empty lines)
    for i <- 11..17 do
      assert Enum.at(lines, i) == "", "Line #{i} should be empty"
    end

    # Amount + currency
    assert Enum.at(lines, 18) == "2500.25"
    assert Enum.at(lines, 19) == "CHF"

    # Debtor address
    assert Enum.at(lines, 20) == "S"
    assert Enum.at(lines, 21) == "Max Muster"

    # Reference
    assert Enum.at(lines, 27) == "QRR"
    assert Enum.at(lines, 28) == ref

    # Additional info + EPD trailer
    assert Enum.at(lines, 29) == "Invoice 2024-001"
    assert Enum.at(lines, 30) == "EPD"
  end

  test "encodes minimal bill (no amount, no debtor, NON reference)" do
    creditor = Address.new("Muster AG", "8001", "Zürich", "CH")

    bill =
      SwissQrBill.new()
      |> SwissQrBill.set_creditor(creditor)
      |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
      |> SwissQrBill.set_payment_amount("CHF")
      |> SwissQrBill.set_payment_reference(:non)

    payload = QrCodeData.encode(bill)
    lines = String.split(payload, "\r\n")

    # Header
    assert Enum.at(lines, 0) == "SPC"

    # Amount should be empty
    assert Enum.at(lines, 18) == ""
    assert Enum.at(lines, 19) == "CHF"

    # Debtor should be empty (7 empty lines)
    for i <- 20..26 do
      assert Enum.at(lines, i) == "", "Line #{i} should be empty"
    end

    # Reference type NON
    assert Enum.at(lines, 27) == "NON"
    assert Enum.at(lines, 28) == ""
  end
end
