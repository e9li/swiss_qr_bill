defmodule SwissQrBill.AlternativeSchemeTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.AlternativeScheme

  describe "new/1" do
    test "creates scheme with parameter" do
      as = AlternativeScheme.new("eBill/B/41010560425610173")
      assert as.parameter == "eBill/B/41010560425610173"
    end
  end

  describe "qr_code_data/1" do
    test "returns parameter in list" do
      as = AlternativeScheme.new("eBill/B/123")
      assert AlternativeScheme.qr_code_data(as) == ["eBill/B/123"]
    end
  end
end
