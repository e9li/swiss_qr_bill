defmodule SwissQrBill.QrCode.QrCode do
  @moduledoc """
  QR code generation for Swiss QR bills.
  Uses the `qr_code` library with Medium error correction.
  """

  # The Swiss standard caps the Swiss QR Code at QR version 25 with ECC
  # level M (max 997 characters / 1273 bytes). The qr_code library would
  # silently pick a larger version for an oversized payload, producing a
  # spec-noncompliant symbol whose modules shrink below the minimum print
  # size in the fixed 46x46 mm area — so reject instead.
  @max_version 25

  @doc """
  Returns the raw QR matrix for rendering in PDF.
  Fails with an error tuple if the payload exceeds QR version #{@max_version}
  (the maximum permitted by the Swiss standard).
  """
  @spec to_matrix(String.t()) :: {:ok, list(list(0 | 1))} | {:error, String.t()}
  def to_matrix(data) do
    case QRCode.create(data, :medium) do
      {:ok, %QRCode.QR{version: version}} when version > @max_version ->
        {:error,
         "QR payload too large: needs QR version #{version}, " <>
           "but the Swiss standard allows at most version #{@max_version}"}

      {:ok, %QRCode.QR{matrix: matrix}} ->
        {:ok, matrix}

      {:error, reason} ->
        {:error, "QR code generation failed: #{inspect(reason)}"}
    end
  end
end
