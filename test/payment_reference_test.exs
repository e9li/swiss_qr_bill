defmodule SwissQrBill.PaymentReferenceTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.PaymentReference

  describe "new/2" do
    test "creates QRR reference" do
      pr = PaymentReference.new(:qrr, "210000000003139471430009017")
      assert pr.type == :qrr
      assert pr.reference == "210000000003139471430009017"
    end

    test "creates SCOR reference" do
      pr = PaymentReference.new(:scor, "RF15I20200631")
      assert pr.type == :scor
      assert pr.reference == "RF15I20200631"
    end

    test "creates NON reference" do
      pr = PaymentReference.new(:non)
      assert pr.type == :non
      assert pr.reference == nil
    end

    test "normalizes reference (strips whitespace)" do
      pr = PaymentReference.new(:qrr, "21 0000 0000 0313 9471 4300 09017")
      assert pr.reference == "210000000003139471430009017"
    end

    test "normalizes empty string to nil" do
      pr = PaymentReference.new(:non, "  ")
      assert pr.reference == nil
    end
  end

  describe "type_string/1" do
    test "QRR" do
      assert PaymentReference.type_string(PaymentReference.new(:qrr, "123")) == "QRR"
    end

    test "SCOR" do
      assert PaymentReference.type_string(PaymentReference.new(:scor, "RF15X")) == "SCOR"
    end

    test "NON" do
      assert PaymentReference.type_string(PaymentReference.new(:non)) == "NON"
    end
  end

  describe "formatted_reference/1" do
    test "QRR in groups of 5 from right" do
      pr = PaymentReference.new(:qrr, "210000000003139471430009017")
      assert PaymentReference.formatted_reference(pr) == "21 00000 00003 13947 14300 09017"
    end

    test "SCOR in groups of 4 from left" do
      pr = PaymentReference.new(:scor, "RF15I20200631")
      assert PaymentReference.formatted_reference(pr) == "RF15 I202 0063 1"
    end

    test "NON returns nil" do
      pr = PaymentReference.new(:non)
      assert PaymentReference.formatted_reference(pr) == nil
    end
  end

  describe "qr_code_data/1" do
    test "returns type string and reference" do
      pr = PaymentReference.new(:qrr, "210000000003139471430009017")
      assert PaymentReference.qr_code_data(pr) == ["QRR", "210000000003139471430009017"]
    end

    test "returns nil reference for NON" do
      pr = PaymentReference.new(:non)
      assert PaymentReference.qr_code_data(pr) == ["NON", nil]
    end
  end
end
