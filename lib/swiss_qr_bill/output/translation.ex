defmodule SwissQrBill.Output.Translation do
  @moduledoc """
  Translations for Swiss QR bill payment part labels.
  Supports German (de), French (fr), Italian (it), English (en), and Romansh (rm).
  """

  @translations %{
    payment_part: %{
      de: "Zahlteil",
      fr: "Section de paiement",
      it: "Sezione di pagamento",
      en: "Payment part",
      rm: "Part da pajament"
    },
    creditor: %{
      de: "Konto / Zahlbar an",
      fr: "Compte / Payable à",
      it: "Conto / Pagabile a",
      en: "Account / Payable to",
      rm: "Conto / Pajabel a"
    },
    reference: %{
      de: "Referenz",
      fr: "Référence",
      it: "Riferimento",
      en: "Reference",
      rm: "Referenza"
    },
    additional_information: %{
      de: "Zusätzliche Informationen",
      fr: "Informations supplémentaires",
      it: "Informazioni supplementari",
      en: "Additional information",
      rm: "Infurmaziuns supplementaras"
    },
    currency: %{
      de: "Währung",
      fr: "Monnaie",
      it: "Valuta",
      en: "Currency",
      rm: "Munaida"
    },
    amount: %{
      de: "Betrag",
      fr: "Montant",
      it: "Importo",
      en: "Amount",
      rm: "Import"
    },
    receipt: %{
      de: "Empfangsschein",
      fr: "Récépissé",
      it: "Ricevuta",
      en: "Receipt",
      rm: "Attest da recepziun"
    },
    acceptance_point: %{
      de: "Annahmestelle",
      fr: "Point de dépôt",
      it: "Punto di accettazione",
      en: "Acceptance point",
      rm: "Lieu d'acceptaziun"
    },
    separate: %{
      de: "Vor der Einzahlung abzutrennen",
      fr: "A détacher avant le versement",
      it: "Da staccare prima del versamento",
      en: "Separate before paying in",
      rm: "Da separar avant il pajament"
    },
    payable_by: %{
      de: "Zahlbar durch",
      fr: "Payable par",
      it: "Pagabile da",
      en: "Payable by",
      rm: "Pajabel da"
    },
    payable_by_name: %{
      de: "Zahlbar durch (Name/Adresse)",
      fr: "Payable par (nom/adresse)",
      it: "Pagabile da (nome/indirizzo)",
      en: "Payable by (name/address)",
      rm: "Pajabel da (num/adressa)"
    },
    in_favor_of: %{
      de: "Zugunsten",
      fr: "En faveur de",
      it: "A favore di",
      en: "In favour of",
      rm: "A favur da"
    },
    do_not_use_for_payment: %{
      de: "NICHT ZUR ZAHLUNG VERWENDEN",
      fr: "NE PAS UTILISER POUR LE PAIEMENT",
      it: "NON UTILIZZARE PER IL PAGAMENTO",
      en: "DO NOT USE FOR PAYMENT",
      rm: "NUN DUVRAR PER IL PAJAMENT"
    }
  }

  @type language :: :de | :fr | :it | :en | :rm

  @doc """
  Returns the translated string for the given key and language.
  """
  @spec get(atom(), language()) :: String.t()
  def get(key, language) do
    @translations
    |> Map.fetch!(key)
    |> Map.fetch!(language)
  end
end
