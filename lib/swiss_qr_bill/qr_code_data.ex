defmodule SwissQrBill.QrCodeData do
  @moduledoc """
  Assembles the QR code data payload per the SIX Swiss QR bill specification.
  The payload is a newline-separated string of fields in a strict order.
  """

  alias SwissQrBill.{Address, CreditorInformation, PaymentAmount, PaymentReference, AdditionalInformation, AlternativeScheme}

  @header_qr_type "SPC"
  @header_version "0200"
  @header_coding "1"

  @doc """
  Encodes a QR bill struct into the QR code data payload string.
  """
  @spec encode(map()) :: String.t()
  def encode(bill) do
    elements =
      []
      |> add_header()
      |> add_creditor_information(bill.creditor_information)
      |> add_address(bill.creditor)
      |> add_empty_address()
      |> add_payment_amount(bill.payment_amount)
      |> add_address_or_empty(bill.debtor)
      |> add_payment_reference(bill.payment_reference)
      |> add_additional_information(bill.additional_information)
      |> maybe_add_empty_line(bill)
      |> add_alternative_schemes(bill.alternative_schemes)

    elements
    |> Enum.reverse()
    |> List.flatten()
    |> Enum.map(&to_field/1)
    |> Enum.join("\r\n")
  end

  defp add_header(elements) do
    [[@header_qr_type, @header_version, @header_coding] | elements]
  end

  defp add_creditor_information(elements, %CreditorInformation{} = ci) do
    [CreditorInformation.qr_code_data(ci) | elements]
  end

  defp add_address(elements, %Address{} = addr) do
    [Address.qr_code_data(addr) | elements]
  end

  # Ultimate creditor placeholder — not used yet per spec
  defp add_empty_address(elements) do
    [Address.empty_qr_code_data() | elements]
  end

  defp add_payment_amount(elements, %PaymentAmount{} = pa) do
    [PaymentAmount.qr_code_data(pa) | elements]
  end

  defp add_address_or_empty(elements, nil) do
    [Address.empty_qr_code_data() | elements]
  end

  defp add_address_or_empty(elements, %Address{} = addr) do
    [Address.qr_code_data(addr) | elements]
  end

  defp add_payment_reference(elements, %PaymentReference{} = pr) do
    [PaymentReference.qr_code_data(pr) | elements]
  end

  defp add_additional_information(elements, nil) do
    [[nil, "EPD"] | elements]
  end

  defp add_additional_information(elements, %AdditionalInformation{} = ai) do
    [AdditionalInformation.qr_code_data(ai) | elements]
  end

  # Per spec: if alternative schemes exist AND bill information is absent,
  # insert an empty line before alternative schemes
  defp maybe_add_empty_line(elements, bill) do
    has_alt_schemes = is_list(bill.alternative_schemes) and bill.alternative_schemes != []
    has_bill_info = bill.additional_information != nil and bill.additional_information.bill_information != nil

    if has_alt_schemes and not has_bill_info do
      [[nil] | elements]
    else
      elements
    end
  end

  defp add_alternative_schemes(elements, nil), do: elements
  defp add_alternative_schemes(elements, []), do: elements

  defp add_alternative_schemes(elements, schemes) when is_list(schemes) do
    Enum.reduce(schemes, elements, fn %AlternativeScheme{} = scheme, acc ->
      [AlternativeScheme.qr_code_data(scheme) | acc]
    end)
  end

  defp to_field(nil), do: ""
  defp to_field(value) when is_binary(value), do: String.trim(value)
  defp to_field(value) when is_integer(value), do: Integer.to_string(value)
end
