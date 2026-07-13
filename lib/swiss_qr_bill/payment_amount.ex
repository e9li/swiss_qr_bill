defmodule SwissQrBill.PaymentAmount do
  @moduledoc """
  Payment amount and currency for Swiss QR bills.
  Amount is optional (nil = blank amount box on payment part).

  The amount is stored as a `Decimal` to avoid floating-point rounding errors.
  `new/2` accepts a `Decimal`, a number (integer or float), or a decimal string.
  """

  @type t :: %__MODULE__{
          currency: String.t(),
          amount: Decimal.t() | nil
        }

  @enforce_keys [:currency]
  defstruct [:currency, :amount]

  @doc """
  Creates payment amount information.
  Amount can be nil (for bills without a fixed amount).
  """
  @spec new(String.t(), Decimal.t() | number() | String.t() | nil) :: t()
  def new(currency, amount \\ nil) do
    %__MODULE__{
      currency: normalize_currency(currency),
      amount: to_decimal(amount)
    }
  end

  # Non-binary currencies are stored as-is so validation reports them
  # ("currency must be CHF or EUR") instead of new/2 crashing.
  defp normalize_currency(c) when is_binary(c), do: c |> String.trim() |> String.upcase()
  defp normalize_currency(c), do: c

  @doc """
  Returns the formatted amount for display (with space as thousands separator).
  Returns empty string if amount is nil.
  """
  @spec formatted_amount(t()) :: String.t()
  def formatted_amount(%__MODULE__{amount: nil}), do: ""

  def formatted_amount(%__MODULE__{amount: %Decimal{} = amount}) do
    amount
    |> two_decimal_string()
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

  def qr_code_data(%__MODULE__{amount: %Decimal{} = amount, currency: currency}) do
    [two_decimal_string(amount), currency]
  end

  # Converts supported inputs to Decimal. Unparseable values are returned as-is
  # so that validation reports them instead of raising here.
  defp to_decimal(nil), do: nil
  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)

  defp to_decimal(s) when is_binary(s) do
    # Only finite decimals: Decimal.parse also accepts "NaN"/"Infinity"
    # (coef :NaN/:inf), which would crash Decimal.compare/2 in validation.
    case Decimal.parse(s) do
      {%Decimal{coef: coef} = d, ""} when is_integer(coef) -> d
      _ -> s
    end
  end

  defp to_decimal(other), do: other

  defp two_decimal_string(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
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
