defmodule SwissQrBill.Reference.CreditorReferenceGenerator do
  @moduledoc """
  Generates RF creditor references per ISO 11649.
  """

  @doc """
  Generates a creditor reference from a reference string.
  The input must be 1-21 alphanumeric characters.

  Returns `{:ok, reference}` with RF prefix and check digits, or `{:error, reason}`.

  ## Example

      iex> SwissQrBill.Reference.CreditorReferenceGenerator.generate("I20200631")
      {:ok, "RF49I20200631"}
  """
  @spec generate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(reference) when is_binary(reference) do
    ref = String.upcase(String.replace(reference, ~r/\s/, ""))

    cond do
      ref == "" ->
        {:error, "reference is required"}

      String.length(ref) > 21 ->
        {:error, "reference must be at most 21 characters"}

      not Regex.match?(~r/^[A-Z0-9]+$/, ref) ->
        {:error, "reference must be alphanumeric"}

      true ->
        # ISO 11649: append "RF00", convert to numeric, compute 98 - (number mod 97)
        check_string = ref <> "RF00"
        numeric_string = letters_to_digits(check_string)
        {number, ""} = Integer.parse(numeric_string)
        check_digits = 98 - rem(number, 97)
        check_str = check_digits |> Integer.to_string() |> String.pad_leading(2, "0")
        {:ok, "RF#{check_str}#{ref}"}
    end
  end

  defp letters_to_digits(string) do
    string
    |> String.graphemes()
    |> Enum.map(fn char ->
      cond do
        char >= "0" and char <= "9" -> char
        char >= "A" and char <= "Z" -> Integer.to_string(String.to_charlist(char) |> hd() |> Kernel.-(65) |> Kernel.+(10))
      end
    end)
    |> Enum.join()
  end
end
