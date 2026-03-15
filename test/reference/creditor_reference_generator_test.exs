defmodule SwissQrBill.Reference.CreditorReferenceGeneratorTest do
  use ExUnit.Case

  alias SwissQrBill.Reference.CreditorReferenceGenerator

  describe "generate/1" do
    test "generates valid RF reference" do
      assert {:ok, ref} = CreditorReferenceGenerator.generate("I20200631")
      assert String.starts_with?(ref, "RF")
      assert String.length(ref) <= 25
    end

    test "known test vector" do
      assert {:ok, "RF15I20200631"} = CreditorReferenceGenerator.generate("I20200631")
    end

    test "validates generated reference" do
      assert {:ok, ref} = CreditorReferenceGenerator.generate("ABC123")
      assert SwissQrBill.Validation.valid_creditor_reference?(ref)
    end

    test "rejects empty reference" do
      assert {:error, _} = CreditorReferenceGenerator.generate("")
    end

    test "rejects too-long reference" do
      assert {:error, _} = CreditorReferenceGenerator.generate(String.duplicate("A", 22))
    end

    test "rejects non-alphanumeric reference" do
      assert {:error, _} = CreditorReferenceGenerator.generate("AB-CD")
    end
  end
end
