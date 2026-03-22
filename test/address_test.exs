defmodule SwissQrBill.AddressTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.Address

  describe "new/6 (with street)" do
    test "creates address with all fields" do
      addr = Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
      assert addr.name == "Muster AG"
      assert addr.street == "Bahnhofstrasse"
      assert addr.building_number == "1"
      assert addr.postal_code == "8001"
      assert addr.city == "Zürich"
      assert addr.country == "CH"
    end

    test "uppercases country code" do
      addr = Address.new("Test", "Street", "1", "1000", "City", "ch")
      assert addr.country == "CH"
    end

    test "trims whitespace" do
      addr = Address.new("  Test  ", " Street ", " 1 ", " 1000 ", " City ", " ch ")
      assert addr.name == "Test"
      assert addr.street == "Street"
      assert addr.building_number == "1"
      assert addr.postal_code == "1000"
      assert addr.city == "City"
      assert addr.country == "CH"
    end

    test "cleans newlines and tabs" do
      addr = Address.new("Test\nName", "Street\t1", "1a", "1000", "City", "CH")
      assert addr.name == "Test Name"
      assert addr.street == "Street 1"
    end

    test "collapses multiple spaces" do
      addr = Address.new("Test    Name", "Street", "1", "1000", "City", "CH")
      assert addr.name == "Test Name"
    end
  end

  describe "new/4 (without street)" do
    test "creates minimal address" do
      addr = Address.new("Muster AG", "8001", "Zürich", "CH")
      assert addr.name == "Muster AG"
      assert addr.street == nil
      assert addr.building_number == nil
      assert addr.postal_code == "8001"
      assert addr.city == "Zürich"
      assert addr.country == "CH"
    end
  end

  describe "address_type/0" do
    test "returns S for structured" do
      assert Address.address_type() == "S"
    end
  end

  describe "qr_code_data/1" do
    test "returns 7 fields for full address" do
      addr = Address.new("Name", "Street", "1", "1000", "City", "CH")
      data = Address.qr_code_data(addr)
      assert length(data) == 7
      assert Enum.at(data, 0) == "S"
      assert Enum.at(data, 1) == "Name"
      assert Enum.at(data, 2) == "Street"
      assert Enum.at(data, 3) == "1"
      assert Enum.at(data, 4) == "1000"
      assert Enum.at(data, 5) == "City"
      assert Enum.at(data, 6) == "CH"
    end

    test "returns nil for missing street fields" do
      addr = Address.new("Name", "1000", "City", "CH")
      data = Address.qr_code_data(addr)
      assert Enum.at(data, 2) == nil
      assert Enum.at(data, 3) == nil
    end
  end

  describe "empty_qr_code_data/0" do
    test "returns 7 nil values" do
      data = Address.empty_qr_code_data()
      assert length(data) == 7
      assert Enum.all?(data, &is_nil/1)
    end
  end

  describe "full_address/1" do
    test "formats address with street" do
      addr = Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
      assert Address.full_address(addr) == "Muster AG\nBahnhofstrasse 1\n8001 Zürich"
    end

    test "formats address without building number" do
      addr = Address.new("Muster AG", "Bahnhofstrasse", nil, "8001", "Zürich", "CH")
      assert Address.full_address(addr) == "Muster AG\nBahnhofstrasse\n8001 Zürich"
    end

    test "formats minimal address" do
      addr = Address.new("Muster AG", "8001", "Zürich", "CH")
      assert Address.full_address(addr) == "Muster AG\n8001 Zürich"
    end
  end
end
