defmodule SwissQrBill.Reference.QrReferenceGenerator do
  @moduledoc """
  Generates 27-digit QR payment references with modulo-10 recursive check digit.
  """

  @mod10_table [0, 9, 4, 6, 8, 2, 7, 1, 3, 5]

  @doc """
  Generates a QR payment reference from an optional customer identification number
  and a reference number.

  ## Parameters
  - `customer_id` — optional BESR-ID from bank (numeric, max 11 digits), can be nil or ""
  - `reference_number` — the reference number (numeric, required)

  ## Returns
  `{:ok, reference}` with the 27-digit reference, or `{:error, reason}`.

  ## Example

      iex> SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")
      {:ok, "210000000003139471430009017"}
  """
  @spec generate(String.t() | nil, String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(customer_id \\ nil, reference_number) do
    customer_id = normalize(customer_id)
    reference_number = normalize(reference_number)

    with :ok <- validate_inputs(customer_id, reference_number) do
      # Customer ID occupies left positions, reference fills right positions, zeros in between
      remaining = 26 - String.length(customer_id)
      padded = customer_id <> String.pad_leading(reference_number, remaining, "0")
      check_digit = compute_check_digit(padded)
      reference = padded <> Integer.to_string(check_digit)

      if String.match?(reference, ~r/^0{27}$/) do
        {:error, "reference must not be all zeros"}
      else
        {:ok, reference}
      end
    end
  end

  @doc """
  Computes the modulo-10 recursive check digit for a numeric string.
  """
  @spec compute_check_digit(String.t()) :: non_neg_integer()
  def compute_check_digit(string) do
    carry =
      string
      |> String.graphemes()
      |> Enum.reduce(0, fn digit, carry ->
        {d, ""} = Integer.parse(digit)
        table_index = rem(carry + d, 10)
        Enum.at(@mod10_table, table_index)
      end)

    rem(10 - carry, 10)
  end

  defp normalize(nil), do: ""
  defp normalize(str), do: String.replace(str, ~r/\s/, "")

  defp validate_inputs(customer_id, reference_number) do
    cond do
      reference_number == "" ->
        {:error, "reference_number is required"}

      not Regex.match?(~r/^\d+$/, reference_number) ->
        {:error, "reference_number must be numeric"}

      customer_id != "" and not Regex.match?(~r/^\d+$/, customer_id) ->
        {:error, "customer_id must be numeric"}

      String.length(customer_id) + String.length(reference_number) > 26 ->
        {:error, "combined length of customer_id and reference_number must not exceed 26"}

      true ->
        :ok
    end
  end
end
