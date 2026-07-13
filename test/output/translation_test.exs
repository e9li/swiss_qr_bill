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
    :do_not_use_for_payment,
    :branding
  ]

  describe "get/2" do
    test "returns non-empty string for all key/language combinations" do
      for key <- @keys, lang <- @languages do
        result = Translation.get(key, lang)

        assert result != "",
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

    test "Romansh separate (Annex C Table 23)" do
      assert Translation.get(:separate, :rm) == "Da distatgar avant che pajar"
    end

    test "French and Italian payment_part match the official short headings" do
      assert Translation.get(:payment_part, :fr) == "Section paiement"
      assert Translation.get(:payment_part, :it) == "Sezione pagamento"
    end

    test "Romansh headings match Annex C Table 23" do
      assert Translation.get(:receipt, :rm) == "Quittanza"
      assert Translation.get(:currency, :rm) == "Valuta"
      assert Translation.get(:creditor, :rm) == "Conto / Da pajar a"
      assert Translation.get(:do_not_use_for_payment, :rm) == "BETG DUVRAR PER IL PAJAMENT"
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
