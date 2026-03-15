defmodule SwissQrBill.QrCode.QrCode do
  @moduledoc """
  QR code generation for Swiss QR bills.
  Uses the `qr_code` library with Medium error correction.
  """

  @doc """
  Returns the raw QR matrix for rendering in PDF.
  """
  @spec to_matrix(String.t()) :: {:ok, list(list(0 | 1))} | {:error, String.t()}
  def to_matrix(data) do
    case QRCode.create(data, :medium) do
      {:ok, %QRCode.QR{matrix: matrix}} ->
        {:ok, matrix}

      {:error, reason} ->
        {:error, "QR code generation failed: #{inspect(reason)}"}
    end
  end
end
