defmodule SwissQrBill.AdditionalInformation do
  @moduledoc """
  Additional information for Swiss QR bills.
  Contains an unstructured message and/or coded bill information.
  """

  @type t :: %__MODULE__{
          message: String.t() | nil,
          bill_information: String.t() | nil
        }

  defstruct [:message, :bill_information]

  @trailer "EPD"

  @doc """
  Creates additional information.
  """
  @spec new(String.t() | nil, String.t() | nil) :: t()
  def new(message \\ nil, bill_information \\ nil) do
    %__MODULE__{
      message: message,
      bill_information: bill_information
    }
  end

  @doc """
  Returns the QR code data fields.
  Always includes the EPD trailer, optionally followed by bill information.
  """
  @spec qr_code_data(t()) :: [String.t() | nil]
  def qr_code_data(%__MODULE__{message: message, bill_information: nil}) do
    [message, @trailer]
  end

  def qr_code_data(%__MODULE__{message: message, bill_information: bill_info}) do
    [message, @trailer, bill_info]
  end

  @doc """
  Returns the formatted string for display.
  """
  @spec formatted_string(t()) :: String.t()
  def formatted_string(%__MODULE__{message: nil, bill_information: nil}), do: ""

  def formatted_string(%__MODULE__{message: msg, bill_information: nil}) when is_binary(msg),
    do: msg

  def formatted_string(%__MODULE__{message: nil, bill_information: bi}) when is_binary(bi),
    do: bi

  def formatted_string(%__MODULE__{message: msg, bill_information: bi}),
    do: "#{msg}\n#{bi}"
end
