defmodule SwissQrBill.Validation do
  @moduledoc """
  Validation logic for Swiss QR bill data.
  """

  alias SwissQrBill.{
    Address,
    CreditorInformation,
    IBAN,
    PaymentAmount,
    PaymentReference,
    AdditionalInformation,
    AlternativeScheme
  }

  require Logger

  @max_amount Decimal.new("999999999.99")
  @min_amount Decimal.new("0.01")

  # Character set permitted in the Swiss QR Code per SIX IG QR-bill §4.1.1:
  # Basic Latin (U+0020-U+007E), Latin-1 Supplement (U+00A0-U+00FF),
  # Latin Extended-A (U+0100-U+017F), plus Ș ș Ț ț (U+0218-U+021B) and € (U+20AC).
  @allowed_chars_regex ~r/^[\x{0020}-\x{007E}\x{00A0}-\x{00FF}\x{0100}-\x{017F}\x{0218}-\x{021B}\x{20AC}]*$/u

  @doc """
  Validates a complete QR bill. Returns `{:ok, bill}` or `{:error, errors}`.
  """
  def validate(bill) do
    errors =
      []
      |> validate_creditor_information(bill)
      |> validate_creditor(bill)
      |> validate_payment_amount(bill)
      |> validate_payment_reference(bill)
      |> validate_creditor_reference_combination(bill)
      |> validate_additional_information(bill)
      |> validate_alternative_schemes(bill)
      |> validate_debtor(bill)
      |> Enum.reverse()

    Enum.each(warnings(bill), &Logger.warning/1)

    case errors do
      [] -> {:ok, bill}
      errors -> {:error, errors}
    end
  end

  @doc """
  Returns non-blocking advisory warnings for a bill (these do not affect validity).

  Currently warns when the QR-IBAN / QR-reference (QRR) combination is used with a
  non-CHF currency. Per SIX IG QR-bill v2.4 this combination is reserved for CHF;
  EUR invoices must use a regular IBAN with a Creditor Reference (SCOR) or no
  reference (NON). It becomes a hard rejection once euroSIC is discontinued
  (EUR QR-bills move to SEPA Credit Transfer by November 2027 at the latest).
  """
  @spec warnings(map()) :: [String.t()]
  def warnings(bill) do
    []
    |> warn_qr_reference_currency(bill)
    |> Enum.reverse()
  end

  defp warn_qr_reference_currency(warnings, bill) do
    currency =
      case Map.get(bill, :payment_amount) do
        %PaymentAmount{currency: c} -> c
        _ -> nil
      end

    qrr? = match?(%PaymentReference{type: :qrr}, Map.get(bill, :payment_reference))

    qr_iban? =
      case Map.get(bill, :creditor_information) do
        %CreditorInformation{} = ci -> CreditorInformation.qr_iban?(ci)
        _ -> false
      end

    if currency == "EUR" and (qrr? or qr_iban?) do
      [
        "QR-IBAN/QR-reference (QRR) is only valid for invoices in CHF (SIX IG QR-bill v2.4). " <>
          "For #{currency} invoices use a regular IBAN with a Creditor Reference (SCOR) or " <>
          "no reference (NON). This will be rejected once euroSIC is discontinued (by November 2027)."
        | warnings
      ]
    else
      warnings
    end
  end

  defp validate_creditor_information(errors, %{creditor_information: nil}) do
    ["creditor_information is required" | errors]
  end

  defp validate_creditor_information(errors, %{
         creditor_information: %CreditorInformation{iban: iban}
       }) do
    case IBAN.validate(iban) do
      {:ok, _} -> errors
      {:error, reason} -> ["invalid IBAN: #{reason}" | errors]
    end
  end

  defp validate_creditor_information(errors, _) do
    ["creditor_information must be a CreditorInformation struct" | errors]
  end

  defp validate_creditor(errors, %{creditor: nil}) do
    ["creditor address is required" | errors]
  end

  defp validate_creditor(errors, %{creditor: addr}) do
    validate_address(errors, addr, "creditor")
  end

  defp validate_payment_amount(errors, %{payment_amount: nil}) do
    ["payment_amount is required" | errors]
  end

  defp validate_payment_amount(errors, %{
         payment_amount: %PaymentAmount{currency: currency, amount: amount}
       }) do
    errors =
      if currency in ["CHF", "EUR"] do
        errors
      else
        ["currency must be CHF or EUR" | errors]
      end

    case amount do
      nil ->
        errors

      # Finite decimals only — NaN/Infinity (coef :NaN/:inf) would crash compare/2
      %Decimal{coef: coef} = a when is_integer(coef) ->
        if Decimal.compare(a, @min_amount) != :lt and Decimal.compare(a, @max_amount) != :gt do
          errors
        else
          ["amount must be between #{@min_amount} and #{@max_amount}" | errors]
        end

      _ ->
        ["amount must be a valid number" | errors]
    end
  end

  defp validate_payment_amount(errors, _) do
    ["payment_amount must be a PaymentAmount struct" | errors]
  end

  defp validate_payment_reference(errors, %{payment_reference: nil}) do
    ["payment_reference is required" | errors]
  end

  defp validate_payment_reference(errors, %{
         payment_reference: %PaymentReference{type: :qrr, reference: ref}
       }) do
    cond do
      is_nil(ref) or ref == "" ->
        ["QRR reference is required" | errors]

      not is_binary(ref) ->
        ["QRR reference must be a string" | errors]

      not Regex.match?(~r/^[0-9]{27}$/, ref) ->
        ["QRR reference must be exactly 27 digits" | errors]

      not valid_mod10_check_digit?(ref) ->
        ["QRR reference has invalid check digit" | errors]

      true ->
        errors
    end
  end

  defp validate_payment_reference(errors, %{
         payment_reference: %PaymentReference{type: :scor, reference: ref}
       }) do
    cond do
      is_nil(ref) or ref == "" ->
        ["SCOR reference is required" | errors]

      not is_binary(ref) ->
        ["SCOR reference must be a string" | errors]

      not valid_creditor_reference?(ref) ->
        ["SCOR reference is invalid (ISO 11649)" | errors]

      true ->
        errors
    end
  end

  defp validate_payment_reference(errors, %{
         payment_reference: %PaymentReference{type: :non, reference: ref}
       }) do
    if is_nil(ref) or ref == "" do
      errors
    else
      ["NON reference type must have no reference" | errors]
    end
  end

  # Hand-built structs can carry any type atom; report instead of raising
  defp validate_payment_reference(errors, %{payment_reference: %PaymentReference{}}) do
    ["payment_reference type must be :qrr, :scor or :non" | errors]
  end

  defp validate_payment_reference(errors, _) do
    ["payment_reference must be a PaymentReference struct" | errors]
  end

  defp validate_creditor_reference_combination(errors, %{
         creditor_information: %CreditorInformation{} = ci,
         payment_reference: %PaymentReference{type: type}
       }) do
    is_qr = CreditorInformation.qr_iban?(ci)

    cond do
      is_qr and type != :qrr ->
        ["QR-IBAN requires QRR reference type" | errors]

      not is_qr and type == :qrr ->
        ["QRR reference type requires QR-IBAN" | errors]

      true ->
        errors
    end
  end

  defp validate_creditor_reference_combination(errors, _), do: errors

  defp validate_additional_information(errors, %{additional_information: nil}), do: errors

  defp validate_additional_information(errors, %{
         additional_information: %AdditionalInformation{message: msg, bill_information: bi}
       }) do
    errors
    |> validate_optional_field(msg, "message", 140)
    |> validate_optional_field(bi, "bill_information", 140)
    |> validate_combined_information_length(msg, bi)
  end

  # Per SIX IG QR-bill §4.3.3 / data element table: the unstructured message and the
  # billing information may together contain at most 140 characters.
  defp validate_combined_information_length(errors, msg, bi) do
    if text_length(msg) + text_length(bi) > 140 do
      ["message and bill_information together must not exceed 140 characters" | errors]
    else
      errors
    end
  end

  # Non-binary values are reported by validate_optional_field; count them as 0
  defp text_length(value) when is_binary(value), do: String.length(value)
  defp text_length(_), do: 0

  defp validate_alternative_schemes(errors, %{alternative_schemes: schemes})
       when is_list(schemes) do
    if length(schemes) > 2 do
      ["maximum 2 alternative schemes allowed" | errors]
    else
      Enum.reduce(schemes, errors, fn
        %AlternativeScheme{parameter: p}, acc ->
          cond do
            is_nil(p) or p == "" ->
              ["alternative scheme parameter is required" | acc]

            not is_binary(p) ->
              ["alternative scheme parameter must be a string" | acc]

            String.length(p) > 100 ->
              ["alternative scheme parameter must be at most 100 characters" | acc]

            not valid_characters?(p) ->
              [
                "alternative scheme parameter contains characters not permitted in the Swiss QR code"
                | acc
              ]

            true ->
              acc
          end

        _other, acc ->
          ["alternative schemes must be AlternativeScheme structs" | acc]
      end)
    end
  end

  defp validate_alternative_schemes(errors, _), do: errors

  defp validate_debtor(errors, %{debtor: nil}), do: errors

  defp validate_debtor(errors, %{debtor: addr}) do
    validate_address(errors, addr, "debtor")
  end

  defp validate_address(errors, %Address{} = addr, field) do
    errors
    |> validate_required_field(addr.name, "#{field} name", 70)
    |> validate_optional_field(addr.street, "#{field} street", 70)
    |> validate_optional_field(addr.building_number, "#{field} building_number", 16)
    |> validate_required_field(addr.postal_code, "#{field} postal_code", 16)
    |> validate_required_field(addr.city, "#{field} city", 35)
    |> validate_country(addr.country, field)
  end

  defp validate_address(errors, _other, field) do
    ["#{field} must be a SwissQrBill.Address struct" | errors]
  end

  defp validate_required_field(errors, value, label, max_length) do
    cond do
      is_nil(value) or value == "" ->
        ["#{label} is required" | errors]

      not is_binary(value) ->
        ["#{label} must be a string" | errors]

      String.length(value) > max_length ->
        ["#{label} must be at most #{max_length} characters" | errors]

      not valid_characters?(value) ->
        ["#{label} contains characters not permitted in the Swiss QR code" | errors]

      true ->
        errors
    end
  end

  defp validate_optional_field(errors, value, _label, _max_length) when value in [nil, ""],
    do: errors

  defp validate_optional_field(errors, value, label, max_length) when is_binary(value) do
    cond do
      String.length(value) > max_length ->
        ["#{label} must be at most #{max_length} characters" | errors]

      not valid_characters?(value) ->
        ["#{label} contains characters not permitted in the Swiss QR code" | errors]

      true ->
        errors
    end
  end

  defp validate_optional_field(errors, _value, label, _max_length) do
    ["#{label} must be a string" | errors]
  end

  defp validate_country(errors, country, field) do
    if is_binary(country) and Regex.match?(~r/^[A-Z]{2}$/, country) do
      errors
    else
      ["#{field} country must be a 2-letter ISO code" | errors]
    end
  end

  @doc """
  Validates the mod-10 recursive check digit of a QR reference.
  Uses the standard Swiss modulo-10 table.
  Returns `false` for empty or non-digit input.
  """
  @spec valid_mod10_check_digit?(String.t()) :: boolean()
  def valid_mod10_check_digit?(reference) do
    is_binary(reference) and Regex.match?(~r/^[0-9]+$/, reference) and
      mod10_carry(reference) == 0
  end

  defp mod10_carry(digits) do
    table = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5]

    digits
    |> String.graphemes()
    |> Enum.reduce(0, fn digit, carry ->
      {d, ""} = Integer.parse(digit)
      table_index = rem(carry + d, 10)
      Enum.at(table, table_index)
    end)
  end

  @doc """
  Validates a creditor reference (ISO 11649 / SCOR format).
  Must start with RF, followed by 2 check digits, then 1-21 alphanumeric chars.
  Check digits are validated using mod-97-10.
  """
  @spec valid_creditor_reference?(String.t()) :: boolean()
  def valid_creditor_reference?(reference) do
    ref = String.upcase(reference)

    with true <- Regex.match?(~r/^RF\d{2}[A-Z0-9]{1,21}$/, ref),
         rearranged <- String.slice(ref, 4..-1//1) <> String.slice(ref, 0, 4),
         numeric_string <- letters_to_digits(rearranged),
         {number, ""} <- Integer.parse(numeric_string) do
      rem(number, 97) == 1
    else
      _ -> false
    end
  end

  @doc """
  Validates that a string contains only characters allowed in Swiss QR codes.
  """
  @spec valid_characters?(String.t()) :: boolean()
  def valid_characters?(string) do
    Regex.match?(@allowed_chars_regex, string)
  end

  defp letters_to_digits(string) do
    string
    |> String.to_charlist()
    |> Enum.map(fn
      c when c >= ?0 and c <= ?9 -> <<c>>
      c when c >= ?A and c <= ?Z -> Integer.to_string(c - ?A + 10)
    end)
    |> Enum.join()
  end
end
