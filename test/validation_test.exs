defmodule SwissQrBill.ValidationTest do
  use ExUnit.Case

  alias SwissQrBill.Validation

  describe "valid_mod10_check_digit?/1" do
    test "valid reference" do
      assert Validation.valid_mod10_check_digit?("210000000003139471430009017")
    end

    test "invalid reference" do
      refute Validation.valid_mod10_check_digit?("210000000003139471430009010")
    end
  end

  describe "valid_creditor_reference?/1" do
    test "valid RF reference" do
      assert Validation.valid_creditor_reference?("RF15I20200631")
    end

    test "invalid RF reference" do
      refute Validation.valid_creditor_reference?("RF00INVALID")
    end

    test "non-RF string" do
      refute Validation.valid_creditor_reference?("NOTANRFREF")
    end
  end

  describe "valid_characters?/1" do
    test "basic ASCII" do
      assert Validation.valid_characters?("Hello World 123")
    end

    test "German umlauts" do
      assert Validation.valid_characters?("Zürich Böhm Müller")
    end

    test "French accents" do
      assert Validation.valid_characters?("Genève café résumé")
    end

    test "rejects emoji" do
      refute Validation.valid_characters?("Hello 🎉")
    end
  end
end
