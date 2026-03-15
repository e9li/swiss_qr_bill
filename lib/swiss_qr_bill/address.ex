defmodule SwissQrBill.Address do
  @moduledoc """
  Structured address for Swiss QR bills (type "S").
  Per v2.3, only structured addresses are allowed.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          street: String.t() | nil,
          building_number: String.t() | nil,
          postal_code: String.t(),
          city: String.t(),
          country: String.t()
        }

  @enforce_keys [:name, :postal_code, :city, :country]
  defstruct [:name, :street, :building_number, :postal_code, :city, :country]

  @address_type "S"

  @doc """
  Creates a structured address with street information.
  """
  @spec new(String.t(), String.t(), String.t(), String.t(), String.t(), String.t()) :: t()
  def new(name, street, building_number, postal_code, city, country) do
    %__MODULE__{
      name: clean(name),
      street: clean(street),
      building_number: clean(building_number),
      postal_code: clean(postal_code),
      city: clean(city),
      country: String.upcase(String.trim(country))
    }
  end

  @doc """
  Creates a structured address without street information.
  """
  @spec new(String.t(), String.t(), String.t(), String.t()) :: t()
  def new(name, postal_code, city, country) do
    %__MODULE__{
      name: clean(name),
      street: nil,
      building_number: nil,
      postal_code: clean(postal_code),
      city: clean(city),
      country: String.upcase(String.trim(country))
    }
  end

  @doc """
  Returns the address type constant ("S" for structured).
  """
  @spec address_type() :: String.t()
  def address_type, do: @address_type

  @doc """
  Returns the QR code data fields for this address.
  """
  @spec qr_code_data(t()) :: [String.t() | nil]
  def qr_code_data(%__MODULE__{} = addr) do
    [
      @address_type,
      addr.name,
      addr.street,
      addr.building_number,
      addr.postal_code,
      addr.city,
      addr.country
    ]
  end

  @doc """
  Returns 7 empty fields (placeholder for empty address positions).
  """
  @spec empty_qr_code_data() :: [nil]
  def empty_qr_code_data do
    [nil, nil, nil, nil, nil, nil, nil]
  end

  @doc """
  Returns the full formatted address as a multi-line string.
  """
  @spec full_address(t()) :: String.t()
  def full_address(%__MODULE__{} = addr) do
    street_line =
      case {addr.street, addr.building_number} do
        {nil, _} -> nil
        {street, nil} -> street
        {street, nr} -> "#{street} #{nr}"
      end

    postal_line = "#{addr.postal_code} #{addr.city}"

    [addr.name, street_line, postal_line]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp clean(nil), do: nil

  defp clean(str) when is_binary(str) do
    str
    |> String.replace(~r/[\r\n\t]/, " ")
    |> String.replace(~r/ {2,}/, " ")
    |> String.trim()
  end
end
