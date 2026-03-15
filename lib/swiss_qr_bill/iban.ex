defmodule SwissQrBill.IBAN do
  @moduledoc """
  IBAN validation, formatting, and QR-IBAN detection for Swiss QR bills.

  Only CH and LI IBANs are supported, as required by the SIX QR-bill standard.

  ## Validation

      iex> SwissQrBill.IBAN.validate("CH93 0076 2011 6238 5295 7")
      {:ok, "CH9300762011623852957"}

      iex> SwissQrBill.IBAN.validate("DE89 3704 0044 0532 0130 00")
      {:error, :unsupported_country}

  ## Formatting

      iex> SwissQrBill.IBAN.format("CH9300762011623852957")
      "CH93 0076 2011 6238 5295 7"
  """

  # CH and LI both have IBAN length 21 and the same BBAN structure:
  # 5 digits (IID) + 12 alphanumeric characters (account number)
  @iban_length 21
  @bban_pattern ~r/^\d{5}[A-Z0-9]{12}$/
  @allowed_countries ["CH", "LI"]

  @doc """
  Validates an IBAN string for use in Swiss QR bills.

  Returns `{:ok, normalized_iban}` if valid, `{:error, reason}` otherwise.

  ## Error reasons

  - `:invalid_format` - not a valid IBAN format (must be 2 letters + 2 digits + alphanumeric)
  - `:unsupported_country` - only CH and LI are supported
  - `:invalid_length` - wrong length (must be 21 for CH/LI)
  - `:invalid_check_digits` - mod-97 check digit verification failed
  - `:invalid_bban` - BBAN structure doesn't match expected pattern
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def validate(iban) when is_binary(iban) do
    normalized = normalize(iban)

    with :ok <- validate_format(normalized),
         :ok <- validate_country(normalized),
         :ok <- validate_length(normalized),
         :ok <- validate_check_digits(normalized),
         :ok <- validate_bban(normalized) do
      {:ok, normalized}
    end
  end

  def validate(_), do: {:error, :invalid_format}

  @doc """
  Returns true if the IBAN is valid for Swiss QR bills.
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(iban) when is_binary(iban) do
    match?({:ok, _}, validate(iban))
  end

  def valid?(_), do: false

  @doc """
  Formats an IBAN in groups of 4 characters separated by spaces.

      iex> SwissQrBill.IBAN.format("CH9300762011623852957")
      "CH93 0076 2011 6238 5295 7"
  """
  @spec format(String.t()) :: String.t()
  def format(iban) when is_binary(iban) do
    iban
    |> normalize()
    |> String.graphemes()
    |> Enum.chunk_every(4)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(" ")
  end

  @doc """
  Returns true if the IBAN is a QR-IBAN.

  A QR-IBAN has an IID (Institution Identification, positions 5-9) in the
  range 30000-31999. QR-IBANs require the QRR reference type.

      iex> SwissQrBill.IBAN.qr_iban?("CH4431999123000889012")
      true

      iex> SwissQrBill.IBAN.qr_iban?("CH9300762011623852957")
      false
  """
  @spec qr_iban?(String.t()) :: boolean()
  def qr_iban?(iban) when is_binary(iban) do
    normalized = normalize(iban)

    case String.slice(normalized, 4, 5) do
      iid when byte_size(iid) == 5 ->
        case Integer.parse(iid) do
          {num, ""} -> num >= 30000 and num <= 31999
          _ -> false
        end

      _ ->
        false
    end
  end

  def qr_iban?(_), do: false

  @doc """
  Normalizes an IBAN by removing whitespace and converting to uppercase.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(iban) when is_binary(iban) do
    iban
    |> String.replace(~r/\s/, "")
    |> String.upcase()
  end

  # --- Private validation steps ---

  defp validate_format(iban) do
    if Regex.match?(~r/^[A-Z]{2}\d{2}[A-Z0-9]+$/, iban) do
      :ok
    else
      {:error, :invalid_format}
    end
  end

  defp validate_country(iban) do
    country = String.slice(iban, 0, 2)

    if country in @allowed_countries do
      :ok
    else
      {:error, :unsupported_country}
    end
  end

  defp validate_length(iban) do
    if String.length(iban) == @iban_length do
      :ok
    else
      {:error, :invalid_length}
    end
  end

  defp validate_check_digits(iban) do
    # ISO 7064 mod-97: move first 4 chars to end, convert letters to numbers, check mod 97 == 1
    rearranged = String.slice(iban, 4..-1//1) <> String.slice(iban, 0, 4)

    numeric_string =
      rearranged
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

    case Integer.parse(numeric_string) do
      {number, ""} ->
        if rem(number, 97) == 1, do: :ok, else: {:error, :invalid_check_digits}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp validate_bban(iban) do
    bban = String.slice(iban, 4..-1//1)

    if Regex.match?(@bban_pattern, bban) do
      :ok
    else
      {:error, :invalid_bban}
    end
  end
end
