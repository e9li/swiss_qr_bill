defmodule SwissQrBill.AlternativeScheme do
  @moduledoc """
  Alternative payment scheme parameter for Swiss QR bills.
  Maximum 2 alternative schemes are allowed per bill.
  """

  @type t :: %__MODULE__{parameter: String.t()}

  @enforce_keys [:parameter]
  defstruct [:parameter]

  @doc """
  Creates an alternative scheme.
  """
  @spec new(String.t()) :: t()
  def new(parameter) do
    %__MODULE__{parameter: parameter}
  end

  @doc """
  Returns the QR code data fields.
  """
  @spec qr_code_data(t()) :: [String.t()]
  def qr_code_data(%__MODULE__{parameter: parameter}) do
    [parameter]
  end
end
