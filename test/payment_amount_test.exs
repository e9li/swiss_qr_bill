defmodule SwissQrBill.PaymentAmountTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.PaymentAmount

  describe "new/1" do
    test "creates with currency only" do
      pa = PaymentAmount.new("CHF")
      assert pa.currency == "CHF"
      assert pa.amount == nil
    end

    test "uppercases currency" do
      pa = PaymentAmount.new("chf")
      assert pa.currency == "CHF"
    end
  end

  describe "new/2" do
    test "creates with currency and amount" do
      pa = PaymentAmount.new("CHF", 2500.25)
      assert pa.currency == "CHF"
      assert pa.amount == 2500.25
    end

    test "creates with nil amount" do
      pa = PaymentAmount.new("EUR", nil)
      assert pa.amount == nil
    end
  end

  describe "formatted_amount/1" do
    test "formats with thousands separator" do
      pa = PaymentAmount.new("CHF", 1_250_000.50)
      assert PaymentAmount.formatted_amount(pa) == "1 250 000.50"
    end

    test "formats small amount" do
      pa = PaymentAmount.new("CHF", 42.00)
      assert PaymentAmount.formatted_amount(pa) == "42.00"
    end

    test "formats amount with two decimals" do
      pa = PaymentAmount.new("CHF", 100.10)
      assert PaymentAmount.formatted_amount(pa) == "100.10"
    end

    test "returns empty string for nil amount" do
      pa = PaymentAmount.new("CHF")
      assert PaymentAmount.formatted_amount(pa) == ""
    end
  end

  describe "qr_code_data/1" do
    test "returns amount and currency" do
      pa = PaymentAmount.new("CHF", 2500.25)
      [amount, currency] = PaymentAmount.qr_code_data(pa)
      assert amount == "2500.25"
      assert currency == "CHF"
    end

    test "returns nil amount and currency when no amount" do
      pa = PaymentAmount.new("CHF")
      assert PaymentAmount.qr_code_data(pa) == [nil, "CHF"]
    end
  end
end
