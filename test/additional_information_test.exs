defmodule SwissQrBill.AdditionalInformationTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.AdditionalInformation

  describe "new/0" do
    test "creates empty" do
      ai = AdditionalInformation.new()
      assert ai.message == nil
      assert ai.bill_information == nil
    end
  end

  describe "new/1" do
    test "creates with message" do
      ai = AdditionalInformation.new("Test message")
      assert ai.message == "Test message"
      assert ai.bill_information == nil
    end
  end

  describe "new/2" do
    test "creates with message and bill info" do
      ai = AdditionalInformation.new("Msg", "//S1/10/123")
      assert ai.message == "Msg"
      assert ai.bill_information == "//S1/10/123"
    end
  end

  describe "qr_code_data/1" do
    test "with message only includes EPD trailer" do
      ai = AdditionalInformation.new("Test")
      assert AdditionalInformation.qr_code_data(ai) == ["Test", "EPD"]
    end

    test "with message and bill info includes EPD and bill info" do
      ai = AdditionalInformation.new("Msg", "//S1/10/123")
      assert AdditionalInformation.qr_code_data(ai) == ["Msg", "EPD", "//S1/10/123"]
    end

    test "with nil message still includes EPD" do
      ai = AdditionalInformation.new()
      assert AdditionalInformation.qr_code_data(ai) == [nil, "EPD"]
    end
  end

  describe "formatted_string/1" do
    test "empty returns empty string" do
      assert AdditionalInformation.formatted_string(AdditionalInformation.new()) == ""
    end

    test "message only returns message" do
      ai = AdditionalInformation.new("Test")
      assert AdditionalInformation.formatted_string(ai) == "Test"
    end

    test "bill info only returns bill info" do
      ai = AdditionalInformation.new(nil, "//S1/10/123")
      assert AdditionalInformation.formatted_string(ai) == "//S1/10/123"
    end

    test "both returns multiline" do
      ai = AdditionalInformation.new("Msg", "//S1/10/123")
      assert AdditionalInformation.formatted_string(ai) == "Msg\n//S1/10/123"
    end
  end
end
