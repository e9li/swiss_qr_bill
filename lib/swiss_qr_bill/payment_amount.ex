defmodule SwissQrBill.PaymentAmount do
  @moduledoc """
  Payment amount and currency for Swiss QR bills.
  Amount is optional (nil = blank amount box on payment part).
  """

  @type t :: %__MODULE__{
          currency: String.t(),
          amount: float() | nil
        }

  @enforce_keys [:currency]
  defstruct [:currency, :amount]

  @doc """
  Creates payment amount information.
  Amount can be nil (for bills without a fixed amount).
  """
  @spec new(String.t(), float() | nil) :: t()
  def new(currency, amount \\ nil) do
    %__MODULE__{
      currency: String.upcase(currency),
      amount: amount
    }
  end

  @doc """
  Returns the formatted amount for display (with space as thousands separator).
  Returns empty string if amount is nil.
  """
  @spec formatted_amount(t()) :: String.t()
  def formatted_amount(%__MODULE__{amount: nil}), do: ""

  def formatted_amount(%__MODULE__{amount: amount}) do
    amount
    |> :erlang.float_to_binary(decimals: 2)
    |> format_with_spaces()
  end

  @doc """
  Returns the QR code data fields.
  Amount is formatted without thousands separator for the QR code.
  """
  @spec qr_code_data(t()) :: [String.t() | nil]
  def qr_code_data(%__MODULE__{amount: nil, currency: currency}) do
    [nil, currency]
  end

  def qr_code_data(%__MODULE__{amount: amount, currency: currency}) do
    [:erlang.float_to_binary(amount / 1, decimals: 2), currency]
  end

  defp format_with_spaces(str) do
    case String.split(str, ".") do
      [integer_part, decimal_part] ->
        formatted_int =
          integer_part
          |> String.graphemes()
          |> Enum.reverse()
          |> Enum.chunk_every(3)
          |> Enum.map(&Enum.reverse/1)
          |> Enum.reverse()
          |> Enum.map(&Enum.join/1)
          |> Enum.join(" ")

        "#{formatted_int}.#{decimal_part}"

      [integer_part] ->
        integer_part
    end
  end
end
