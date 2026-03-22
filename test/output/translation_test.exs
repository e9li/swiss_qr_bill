defmodule SwissQrBill.Output.TranslationTest do
  use ExUnit.Case, async: true

  alias SwissQrBill.Output.Translation

  @languages [:de, :fr, :it, :en, :rm]

  @keys [
    :payment_part,
    :creditor,
    :reference,
    :additional_information,
    :currency,
    :amount,
    :receipt,
    :acceptance_point,
    :separate,
    :payable_by,
    :payable_by_name,
    :in_favor_of,
    :do_not_use_for_payment
  ]

  describe "get/2" do
    test "returns non-empty string for all key/language combinations" do
      for key <- @keys, lang <- @languages do
        result = Translation.get(key, lang)
        assert is_binary(result) and result != "",
               "Missing translation for #{key}/#{lang}"
      end
    end

    test "German payment_part" do
      assert Translation.get(:payment_part, :de) == "Zahlteil"
    end

    test "French receipt" do
      assert Translation.get(:receipt, :fr) == "Récépissé"
    end

    test "Italian amount" do
      assert Translation.get(:amount, :it) == "Importo"
    end

    test "English creditor" do
      assert Translation.get(:creditor, :en) == "Account / Payable to"
    end

    test "Romansh separate" do
      assert Translation.get(:separate, :rm) == "Da separar avant il pajament"
    end

    test "raises for unknown key" do
      assert_raise KeyError, fn ->
        Translation.get(:nonexistent, :de)
      end
    end

    test "raises for unknown language" do
      assert_raise KeyError, fn ->
        Translation.get(:payment_part, :xx)
      end
    end
  end
end
