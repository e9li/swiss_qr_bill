defmodule SwissQrBill do
  @moduledoc """
  Swiss QR-bill generation library per SIX IG QR-bill v2.3.

  Generates the complete payment part (Zahlteil) with receipt in three output formats:
  PDF, SVG (text as paths), and PNG (rasterized at configurable DPI).

  ## Output formats

  - `to_pdf/2` — native PDF (no system dependencies)
  - `to_svg/2` — SVG with text converted to paths (requires `pdftocairo`)
  - `to_png/2` — rasterized PNG at configurable DPI (requires `pdftocairo`)

  ## Output sizes

  - `:payment_slip` — 210 x 105 mm (default)
  - `:a4` — 210 x 297 mm (payment slip at bottom)
  - `:qr_code` — 56 x 56 mm (QR code only)

  ## Languages

  `:de`, `:fr`, `:it`, `:en`, `:rm` (Romansh)

  ## Usage

      creditor = SwissQrBill.Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
      debtor = SwissQrBill.Address.new("Max Muster", "Hauptstrasse", "42", "3000", "Bern", "CH")
      {:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")

      bill =
        SwissQrBill.new()
        |> SwissQrBill.set_creditor(creditor)
        |> SwissQrBill.set_creditor_information("CH44 3199 9123 0008 8901 2")
        |> SwissQrBill.set_payment_amount("CHF", 2500.25)
        |> SwissQrBill.set_debtor(debtor)
        |> SwissQrBill.set_payment_reference(:qrr, ref)
        |> SwissQrBill.set_additional_information("Invoice 2024-001")

      {:ok, pdf} = SwissQrBill.to_pdf(bill, language: :de)
      {:ok, svg} = SwissQrBill.to_svg(bill, language: :de)
      {:ok, png} = SwissQrBill.to_png(bill, language: :de, dpi: 300)
  """

  alias SwissQrBill.{
    Address,
    CreditorInformation,
    PaymentAmount,
    PaymentReference,
    AdditionalInformation,
    AlternativeScheme,
    Validation
  }

  alias SwissQrBill.Output.{PdfOutput, SvgOutput, PngOutput}

  @type t :: %__MODULE__{
          creditor_information: CreditorInformation.t() | nil,
          creditor: Address.t() | nil,
          payment_amount: PaymentAmount.t() | nil,
          debtor: Address.t() | nil,
          payment_reference: PaymentReference.t() | nil,
          additional_information: AdditionalInformation.t() | nil,
          alternative_schemes: [AlternativeScheme.t()]
        }

  defstruct [
    :creditor_information,
    :creditor,
    :payment_amount,
    :debtor,
    :payment_reference,
    :additional_information,
    alternative_schemes: []
  ]

  @doc """
  Creates a new empty QR bill.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Sets the creditor address.
  """
  @spec set_creditor(t(), Address.t()) :: t()
  def set_creditor(%__MODULE__{} = bill, %Address{} = address) do
    %{bill | creditor: address}
  end

  @doc """
  Sets the creditor IBAN. Accepts an IBAN string or a CreditorInformation struct.
  """
  @spec set_creditor_information(t(), String.t() | CreditorInformation.t()) :: t()
  def set_creditor_information(%__MODULE__{} = bill, iban) when is_binary(iban) do
    %{bill | creditor_information: CreditorInformation.new(iban)}
  end

  def set_creditor_information(%__MODULE__{} = bill, %CreditorInformation{} = ci) do
    %{bill | creditor_information: ci}
  end

  @doc """
  Sets the payment amount. Amount can be nil for bills without a fixed amount.
  """
  @spec set_payment_amount(t(), String.t(), float() | nil) :: t()
  def set_payment_amount(%__MODULE__{} = bill, currency, amount \\ nil) do
    %{bill | payment_amount: PaymentAmount.new(currency, amount)}
  end

  @doc """
  Sets the debtor address. Optional.
  """
  @spec set_debtor(t(), Address.t()) :: t()
  def set_debtor(%__MODULE__{} = bill, %Address{} = address) do
    %{bill | debtor: address}
  end

  @doc """
  Sets the payment reference.
  """
  @spec set_payment_reference(t(), PaymentReference.reference_type(), String.t() | nil) :: t()
  def set_payment_reference(%__MODULE__{} = bill, type, reference \\ nil) do
    %{bill | payment_reference: PaymentReference.new(type, reference)}
  end

  @doc """
  Sets additional information (unstructured message and/or bill information).
  """
  @spec set_additional_information(t(), String.t() | nil, String.t() | nil) :: t()
  def set_additional_information(%__MODULE__{} = bill, message, bill_information \\ nil) do
    %{bill | additional_information: AdditionalInformation.new(message, bill_information)}
  end

  @doc """
  Adds an alternative scheme. Maximum 2 allowed.
  """
  @spec add_alternative_scheme(t(), String.t()) :: t()
  def add_alternative_scheme(%__MODULE__{} = bill, parameter) do
    %{bill | alternative_schemes: bill.alternative_schemes ++ [AlternativeScheme.new(parameter)]}
  end

  @doc """
  Validates the QR bill data.
  Returns `{:ok, bill}` or `{:error, errors}`.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [String.t()]}
  def validate(%__MODULE__{} = bill) do
    Validation.validate(bill)
  end

  @doc """
  Generates the complete payment part as PDF binary.
  Validates the bill first.

  ## Options
  - `:language` — `:de`, `:fr`, `:it`, `:en`, or `:rm` (default: `:de`)
  - `:output_size` — `:payment_slip` (210x105mm), `:a4` (210x297mm), or `:qr_code` (56x56mm). Default: `:payment_slip`
  """
  @spec to_pdf(t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def to_pdf(%__MODULE__{} = bill, opts \\ []) do
    with {:ok, bill} <- validate(bill) do
      PdfOutput.render(bill, opts)
    end
  end

  @doc """
  Generates the complete payment part as SVG.
  Text is converted to glyph outlines (paths) for guaranteed rendering on all devices.
  Requires `pdftocairo` (poppler-utils) to be installed.

  ## Options
  - `:language` — `:de`, `:fr`, `:it`, `:en`, or `:rm` (default: `:de`)
  - `:output_size` — `:payment_slip` (210x105mm), `:a4` (210x297mm), or `:qr_code` (56x56mm). Default: `:payment_slip`
  """
  @spec to_svg(t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def to_svg(%__MODULE__{} = bill, opts \\ []) do
    with {:ok, bill} <- validate(bill) do
      SvgOutput.render(bill, opts)
    end
  end

  @doc """
  Generates the complete payment part as PNG.
  Rasterized from the PDF at the specified DPI for print-quality output.
  Requires `pdftocairo` (poppler-utils) to be installed.

  ## Options
  - `:language` — `:de`, `:fr`, `:it`, `:en`, or `:rm` (default: `:de`)
  - `:output_size` — `:payment_slip` (210x105mm), `:a4` (210x297mm), or `:qr_code` (56x56mm). Default: `:payment_slip`
  - `:dpi` — resolution (default: 300)
  """
  @spec to_png(t(), keyword()) :: {:ok, binary()} | {:error, any()}
  def to_png(%__MODULE__{} = bill, opts \\ []) do
    with {:ok, bill} <- validate(bill) do
      PngOutput.render(bill, opts)
    end
  end
end
