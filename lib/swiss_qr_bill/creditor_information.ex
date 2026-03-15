defmodule SwissQrBill.CreditorInformation do
  @moduledoc """
  Holds the creditor's IBAN and provides QR-IBAN detection.
  """

  alias SwissQrBill.IBAN

  @type t :: %__MODULE__{iban: String.t()}

  @enforce_keys [:iban]
  defstruct [:iban]

  @doc """
  Creates creditor information from an IBAN string.
  Whitespace is stripped and the IBAN is uppercased.
  """
  @spec new(String.t()) :: t()
  def new(iban) do
    %__MODULE__{iban: IBAN.normalize(iban)}
  end

  @doc """
  Returns true if the IBAN is a QR-IBAN (IID in range 30000-31999).
  QR-IBANs have the institution identification at positions 5-9 (1-indexed).
  """
  @spec qr_iban?(t()) :: boolean()
  def qr_iban?(%__MODULE__{iban: iban}) do
    IBAN.qr_iban?(iban)
  end

  @doc """
  Returns the IBAN formatted in groups of 4.
  """
  @spec formatted_iban(t()) :: String.t()
  def formatted_iban(%__MODULE__{iban: iban}) do
    IBAN.format(iban)
  end

  @doc """
  Returns the QR code data fields.
  """
  @spec qr_code_data(t()) :: [String.t()]
  def qr_code_data(%__MODULE__{iban: iban}) do
    [iban]
  end
end
