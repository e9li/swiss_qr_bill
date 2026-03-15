defmodule SwissQrBill.Reference.QrReferenceGeneratorTest do
  use ExUnit.Case

  alias SwissQrBill.Reference.QrReferenceGenerator

  describe "generate/2" do
    test "generates valid 27-digit reference" do
      assert {:ok, ref} = QrReferenceGenerator.generate("210000", "313947143000901")
      assert String.length(ref) == 27
      assert Regex.match?(~r/^\d{27}$/, ref)
    end

    test "known test vector" do
      assert {:ok, "210000000003139471430009017"} =
               QrReferenceGenerator.generate("210000", "313947143000901")
    end

    test "generates reference without customer_id" do
      assert {:ok, ref} = QrReferenceGenerator.generate(nil, "123456")
      assert String.length(ref) == 27
    end

    test "pads short references" do
      assert {:ok, ref} = QrReferenceGenerator.generate(nil, "1")
      assert String.length(ref) == 27
      # Reference "1" right-aligned in 26 chars + check digit
      assert String.starts_with?(ref, "0000000000000000000000000")
    end

    test "rejects non-numeric reference" do
      assert {:error, _} = QrReferenceGenerator.generate(nil, "ABC")
    end

    test "rejects empty reference" do
      assert {:error, _} = QrReferenceGenerator.generate(nil, "")
    end

    test "rejects too-long combined input" do
      assert {:error, _} = QrReferenceGenerator.generate("12345678901", "1234567890123456")
    end

    test "rejects all-zeros reference" do
      assert {:error, _} = QrReferenceGenerator.generate(nil, "0")
    end
  end

  describe "compute_check_digit/1" do
    test "computes correct check digit" do
      # For reference "210000000003139471430009017", the check digit of the first 26 chars should be 7
      assert QrReferenceGenerator.compute_check_digit("21000000000313947143000901") == 7
    end
  end
end
