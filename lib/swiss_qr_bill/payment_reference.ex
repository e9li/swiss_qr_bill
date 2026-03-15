defmodule SwissQrBill.PaymentReference do
  @moduledoc """
  Payment reference information for Swiss QR bills.

  Reference types:
  - `:qrr` — QR payment reference (27 digits, used with QR-IBAN)
  - `:scor` — Creditor Reference / ISO 11649 (RF prefix, used with regular IBAN)
  - `:non` — No reference
  """

  @type reference_type :: :qrr | :scor | :non
  @type t :: %__MODULE__{
          type: reference_type(),
          reference: String.t() | nil
        }

  @enforce_keys [:type]
  defstruct [:type, :reference]

  @type_to_string %{qrr: "QRR", scor: "SCOR", non: "NON"}

  @doc """
  Creates a payment reference.
  """
  @spec new(reference_type(), String.t() | nil) :: t()
  def new(type, reference \\ nil) do
    %__MODULE__{
      type: type,
      reference: normalize_reference(reference)
    }
  end

  @doc """
  Returns the reference type as a string per spec ("QRR", "SCOR", "NON").
  """
  @spec type_string(t()) :: String.t()
  def type_string(%__MODULE__{type: type}) do
    Map.fetch!(@type_to_string, type)
  end

  @doc """
  Returns the formatted reference for display.
  - QRR: groups of 5 from the right
  - SCOR: groups of 4 from the left
  - NON: nil
  """
  @spec formatted_reference(t()) :: String.t() | nil
  def formatted_reference(%__MODULE__{type: :non}), do: nil

  def formatted_reference(%__MODULE__{type: :qrr, reference: ref}) when is_binary(ref) do
    ref
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(5)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(" ")
  end

  def formatted_reference(%__MODULE__{type: :scor, reference: ref}) when is_binary(ref) do
    ref
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(" ")
  end

  @doc """
  Returns the QR code data fields.
  """
  @spec qr_code_data(t()) :: [String.t() | nil]
  def qr_code_data(%__MODULE__{} = pr) do
    [type_string(pr), pr.reference]
  end

  defp normalize_reference(nil), do: nil

  defp normalize_reference(ref) when is_binary(ref) do
    cleaned = String.replace(ref, ~r/\s/, "")
    if cleaned == "", do: nil, else: cleaned
  end
end
