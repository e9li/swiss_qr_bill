defmodule SwissQrBill.IBANTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.IBAN

  doctest SwissQrBill.IBAN

  describe "validate/1" do
    test "valid CH IBAN" do
      assert {:ok, "CH9300762011623852957"} = IBAN.validate("CH9300762011623852957")
    end

    test "valid CH IBAN with spaces" do
      assert {:ok, "CH9300762011623852957"} = IBAN.validate("CH93 0076 2011 6238 5295 7")
    end

    test "valid CH IBAN lowercase" do
      assert {:ok, "CH9300762011623852957"} = IBAN.validate("ch9300762011623852957")
    end

    test "valid LI IBAN" do
      assert {:ok, "LI21088100002324013AA"} = IBAN.validate("LI21 0881 0000 2324 013A A")
    end

    test "valid QR-IBAN" do
      assert {:ok, "CH4431999123000889012"} = IBAN.validate("CH44 3199 9123 0008 8901 2")
    end

    test "rejects non-CH/LI country" do
      assert {:error, :unsupported_country} = IBAN.validate("DE89370400440532013000")
    end

    test "rejects invalid format" do
      assert {:error, :invalid_format} = IBAN.validate("not-an-iban")
    end

    test "rejects empty string" do
      assert {:error, :invalid_format} = IBAN.validate("")
    end

    test "rejects non-binary input" do
      assert {:error, :invalid_format} = IBAN.validate(12345)
      assert {:error, :invalid_format} = IBAN.validate(nil)
    end

    test "rejects wrong length" do
      assert {:error, :invalid_length} = IBAN.validate("CH930076201162385295")
    end

    test "rejects invalid check digits" do
      assert {:error, :invalid_check_digits} = IBAN.validate("CH0000762011623852957")
    end

    test "rejects invalid BBAN structure" do
      # BBAN must be 5 digits + 12 alphanumeric; here we use special chars
      assert {:error, :invalid_format} = IBAN.validate("CH93 0076-2011-6238-529")
    end
  end

  describe "valid?/1" do
    test "returns true for valid IBAN" do
      assert IBAN.valid?("CH9300762011623852957")
    end

    test "returns false for invalid IBAN" do
      refute IBAN.valid?("CH0000000000000000000")
    end

    test "returns false for non-binary" do
      refute IBAN.valid?(nil)
    end
  end

  describe "format/1" do
    test "formats IBAN in groups of 4" do
      assert "CH93 0076 2011 6238 5295 7" = IBAN.format("CH9300762011623852957")
    end

    test "handles already-formatted input" do
      assert "CH93 0076 2011 6238 5295 7" = IBAN.format("CH93 0076 2011 6238 5295 7")
    end
  end

  describe "qr_iban?/1" do
    test "detects QR-IBAN (IID 31999)" do
      assert IBAN.qr_iban?("CH4431999123000889012")
    end

    test "detects QR-IBAN (IID 30000)" do
      assert IBAN.qr_iban?("CH5630000123000889012")
    end

    test "rejects regular IBAN (IID outside range)" do
      refute IBAN.qr_iban?("CH9300762011623852957")
    end

    test "rejects non-binary" do
      refute IBAN.qr_iban?(nil)
    end

    test "handles formatted input with spaces" do
      assert IBAN.qr_iban?("CH44 3199 9123 0008 8901 2")
    end
  end

  describe "normalize/1" do
    test "strips spaces and uppercases" do
      assert "CH9300762011623852957" = IBAN.normalize("ch93 0076 2011 6238 5295 7")
    end
  end
end
