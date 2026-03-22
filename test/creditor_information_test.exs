defmodule SwissQrBill.CreditorInformationTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.CreditorInformation

  describe "new/1" do
    test "normalizes IBAN" do
      ci = CreditorInformation.new("CH44 3199 9123 0008 8901 2")
      assert ci.iban == "CH4431999123000889012"
    end

    test "uppercases IBAN" do
      ci = CreditorInformation.new("ch4431999123000889012")
      assert ci.iban == "CH4431999123000889012"
    end
  end

  describe "qr_iban?/1" do
    test "detects QR-IBAN" do
      ci = CreditorInformation.new("CH4431999123000889012")
      assert CreditorInformation.qr_iban?(ci)
    end

    test "detects regular IBAN" do
      ci = CreditorInformation.new("CH9300762011623852957")
      refute CreditorInformation.qr_iban?(ci)
    end
  end

  describe "formatted_iban/1" do
    test "formats IBAN in groups of 4" do
      ci = CreditorInformation.new("CH4431999123000889012")
      assert CreditorInformation.formatted_iban(ci) == "CH44 3199 9123 0008 8901 2"
    end
  end

  describe "qr_code_data/1" do
    test "returns IBAN in list" do
      ci = CreditorInformation.new("CH4431999123000889012")
      assert CreditorInformation.qr_code_data(ci) == ["CH4431999123000889012"]
    end
  end
end
