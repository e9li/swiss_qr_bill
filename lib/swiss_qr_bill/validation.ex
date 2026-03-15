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

  @max_amount 999_999_999.99

  # Unicode ranges allowed in Swiss QR code per spec
  # Basic Latin (U+0020-U+007E), Latin-1 Supplement (U+00A0-U+00FF),
  # Latin Extended-A (U+0100-U+017F)
  @allowed_chars_regex ~r/^[\x{0020}-\x{007E}\x{00A0}-\x{00FF}\x{0100}-\x{017F}]*$/u

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

    case errors do
      [] -> {:ok, bill}
      errors -> {:error, errors}
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
      nil -> errors
      a when is_number(a) and a >= 0 and a <= @max_amount -> errors
      _ -> ["amount must be between 0 and #{@max_amount}" | errors]
    end
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
    errors =
      if is_binary(msg) and String.length(msg) > 140 do
        ["message must be at most 140 characters" | errors]
      else
        errors
      end

    if is_binary(bi) and String.length(bi) > 140 do
      ["bill_information must be at most 140 characters" | errors]
    else
      errors
    end
  end

  defp validate_alternative_schemes(errors, %{alternative_schemes: schemes})
       when is_list(schemes) do
    if length(schemes) > 2 do
      ["maximum 2 alternative schemes allowed" | errors]
    else
      Enum.reduce(schemes, errors, fn %AlternativeScheme{parameter: p}, acc ->
        cond do
          is_nil(p) or p == "" ->
            ["alternative scheme parameter is required" | acc]

          String.length(p) > 100 ->
            ["alternative scheme parameter must be at most 100 characters" | acc]

          true ->
            acc
        end
      end)
    end
  end

  defp validate_alternative_schemes(errors, _), do: errors

  defp validate_debtor(errors, %{debtor: nil}), do: errors

  defp validate_debtor(errors, %{debtor: addr}) do
    validate_address(errors, addr, "debtor")
  end

  defp validate_address(errors, %Address{} = addr, field) do
    errors =
      if is_nil(addr.name) or addr.name == "" do
        ["#{field} name is required" | errors]
      else
        if String.length(addr.name) > 70 do
          ["#{field} name must be at most 70 characters" | errors]
        else
          errors
        end
      end

    errors =
      if is_binary(addr.street) and String.length(addr.street) > 70 do
        ["#{field} street must be at most 70 characters" | errors]
      else
        errors
      end

    errors =
      if is_binary(addr.building_number) and String.length(addr.building_number) > 16 do
        ["#{field} building_number must be at most 16 characters" | errors]
      else
        errors
      end

    errors =
      if is_nil(addr.postal_code) or addr.postal_code == "" do
        ["#{field} postal_code is required" | errors]
      else
        if String.length(addr.postal_code) > 16 do
          ["#{field} postal_code must be at most 16 characters" | errors]
        else
          errors
        end
      end

    errors =
      if is_nil(addr.city) or addr.city == "" do
        ["#{field} city is required" | errors]
      else
        if String.length(addr.city) > 35 do
          ["#{field} city must be at most 35 characters" | errors]
        else
          errors
        end
      end

    if is_nil(addr.country) or not Regex.match?(~r/^[A-Z]{2}$/, addr.country) do
      ["#{field} country must be a 2-letter ISO code" | errors]
    else
      errors
    end
  end

  @doc """
  Validates the mod-10 recursive check digit of a QR reference.
  Uses the standard Swiss modulo-10 table.
  """
  @spec valid_mod10_check_digit?(String.t()) :: boolean()
  def valid_mod10_check_digit?(reference) do
    table = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5]

    carry =
      reference
      |> String.graphemes()
      |> Enum.reduce(0, fn digit, carry ->
        {d, ""} = Integer.parse(digit)
        table_index = rem(carry + d, 10)
        Enum.at(table, table_index)
      end)

    carry == 0
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
    |> String.graphemes()
    |> Enum.map(fn char ->
      cond do
        char >= "0" and char <= "9" ->
          char

        char >= "A" and char <= "Z" ->
          Integer.to_string(String.to_charlist(char) |> hd() |> Kernel.-(65) |> Kernel.+(10))
      end
    end)
    |> Enum.join()
  end
end
