# SwissQrBill

Swiss QR-bill generation library for Elixir, implementing the [SIX QR-bill standard (v2.3)](https://www.six-group.com/dam/download/banking-services/standardization/qr-bill/ig-qr-bill-v2.3-en.pdf).

Generates the complete payment part (Zahlteil) with receipt as PDF, SVG, or PNG — ready for printing or embedding in invoices.

## Issues & Feedback

This library is developed at [git.e9li.com](https://git.e9li.com/e9li/swiss_qr_bill) and mirrored to [GitHub](https://github.com/e9li/swiss_qr_bill).
If you found a bug or have a suggestion, you can either:

- Open an issue on [GitHub](https://github.com/e9li/swiss_qr_bill/issues)
- Send an email to rafael@e9li.com

## Installation

Add `swiss_qr_bill` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:swiss_qr_bill, "~> 0.1.1"}
  ]
end
```

### System requirements

PDF output works out of the box. For SVG and PNG output, you need `pdftocairo` from the Poppler utilities:

- **macOS:** `brew install poppler`
- **Ubuntu/Debian:** `apt install poppler-utils`
- **Alpine:** `apk add poppler-utils`

## Usage

### Building a QR bill

```elixir
# Create addresses
creditor = SwissQrBill.Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zürich", "CH")
debtor = SwissQrBill.Address.new("Max Muster", "Hauptstrasse", "42", "3000", "Bern", "CH")

# Address without street (minimal form)
creditor = SwissQrBill.Address.new("Muster AG", "8001", "Zürich", "CH")

# Generate a QR reference
{:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")

# Build the bill
bill =
  SwissQrBill.new()
  |> SwissQrBill.set_creditor(creditor)
  |> SwissQrBill.set_creditor_information("CH44 3199 9123 0008 8901 2")
  |> SwissQrBill.set_payment_amount("CHF", 2500.25)
  |> SwissQrBill.set_debtor(debtor)
  |> SwissQrBill.set_payment_reference(:qrr, ref)
  |> SwissQrBill.set_additional_information("Invoice 2024-001")
```

### Validation

```elixir
{:ok, bill} = SwissQrBill.validate(bill)
# or
{:error, errors} = SwissQrBill.validate(invalid_bill)
# errors is a list of descriptive strings
```

Validates IBAN format, QR-IBAN/reference-type compatibility, address fields, character sets, and more.

### PDF output

```elixir
{:ok, pdf_binary} = SwissQrBill.to_pdf(bill, language: :de)
File.write!("qr_bill.pdf", pdf_binary)
```

### SVG output

Text is converted to glyph outlines (paths), so the output renders identically on all devices — no font installation required.

```elixir
{:ok, svg_binary} = SwissQrBill.to_svg(bill, language: :de)
File.write!("qr_bill.svg", svg_binary)
```

### PNG output

Rasterized from the PDF at configurable DPI for print-quality output.

```elixir
{:ok, png_binary} = SwissQrBill.to_png(bill, language: :de, dpi: 300)
File.write!("qr_bill.png", png_binary)
```

### Output sizes

All three formats support the `:output_size` option:

| Value | Dimensions | Description |
|-------|-----------|-------------|
| `:payment_slip` | 210 x 105 mm | Payment part with receipt (default) |
| `:a4` | 210 x 297 mm | Full A4 page with payment part at bottom |
| `:qr_code` | 56 x 56 mm | QR code only |

```elixir
{:ok, pdf} = SwissQrBill.to_pdf(bill, language: :de, output_size: :a4)
{:ok, svg} = SwissQrBill.to_svg(bill, output_size: :qr_code)
{:ok, png} = SwissQrBill.to_png(bill, output_size: :a4, dpi: 150)
```

### Languages

The `:language` option supports five languages. Defaults to `:de`.

| Code | Language |
|------|----------|
| `:de` | Deutsch (German) |
| `:fr` | Français (French) |
| `:it` | Italiano (Italian) |
| `:en` | English |
| `:rm` | Rumantsch (Romansh) |

```elixir
{:ok, pdf} = SwissQrBill.to_pdf(bill, language: :fr)
```

## Reference generators

### QR reference (QRR)

Used with QR-IBANs (IID 30000-31999). Generates a 27-digit reference with mod-10 check digit.

```elixir
# With customer ID (BESR-ID) and reference number
{:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")
#=> {:ok, "210000000003139471430009017"}

# With reference number only
{:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("313947143000901")
#=> {:ok, "000000000003139471430009018"}
```

### Creditor reference (SCOR)

ISO 11649 creditor reference with RF prefix. Used with regular IBANs.

```elixir
{:ok, ref} = SwissQrBill.Reference.CreditorReferenceGenerator.generate("I20200631")
#=> {:ok, "RF15I20200631"}
```

### No reference (NON)

```elixir
bill = SwissQrBill.set_payment_reference(bill, :non)
```

## IBAN utilities

```elixir
# Validate an IBAN
{:ok, normalized} = SwissQrBill.IBAN.validate("CH44 3199 9123 0008 8901 2")
#=> {:ok, "CH4431999123000889012"}

# Check if it's a QR-IBAN
SwissQrBill.IBAN.qr_iban?("CH4431999123000889012")
#=> true

# Format an IBAN
SwissQrBill.IBAN.format("CH4431999123000889012")
#=> "CH44 3199 9123 0008 8901 2"
```

## Reference type and IBAN compatibility

| IBAN type  | Allowed reference types |
|------------|------------------------|
| QR-IBAN    | `:qrr` only            |
| Regular    | `:scor` or `:non`      |

QR-IBANs are identified by their IID (positions 5-9) being in the range 30000-31999.

## Minimal bill (no amount, no debtor)

```elixir
bill =
  SwissQrBill.new()
  |> SwissQrBill.set_creditor(SwissQrBill.Address.new("Muster AG", "8001", "Zürich", "CH"))
  |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
  |> SwissQrBill.set_payment_amount("CHF")
  |> SwissQrBill.set_payment_reference(:non)

{:ok, pdf} = SwissQrBill.to_pdf(bill)
```

When amount or debtor are omitted, placeholder corner marks are rendered per the SIX style guide.

## Alternative schemes

Up to 2 alternative payment schemes can be added (e.g. eBill):

```elixir
bill =
  bill
  |> SwissQrBill.add_alternative_scheme("eBill/B/41010560425610173")
  |> SwissQrBill.add_alternative_scheme("//S1/10/10201409/11/190512")
```

## Output layout

The payment slip renders the complete payment part (210 x 105 mm):

- **Receipt** (left, 62 mm) — creditor, reference, amount, acceptance point
- **Payment part** (right, 148 mm) — QR code with Swiss cross, creditor, reference, additional information, amount, debtor

The layout follows the [SIX style guide](https://www.six-group.com/dam/download/banking-services/standardization/qr-bill/style-guide-qr-bill-en.pdf) specifications.

## Validation constraints

| Field | Constraint |
|-------|-----------|
| Amount | 0 to 999,999,999.99 |
| Currency | CHF or EUR |
| Creditor name | Max 70 characters |
| Creditor street | Max 70 characters |
| Building number | Max 16 characters |
| Postal code | Max 16 characters |
| City | Max 35 characters |
| Country | 2-letter ISO code |
| Message | Max 140 characters |
| Bill information | Max 140 characters |
| Alt. scheme parameter | Max 100 characters |
| Alternative schemes | Max 2 |
| IBAN | CH or LI, 21 characters |
| QRR reference | 27 digits, valid mod-10 |
| SCOR reference | RF + check digits + 1-21 alphanumeric |

## Dependencies

- [`qr_code`](https://hex.pm/packages/qr_code) — QR code generation
- [`pdf`](https://hex.pm/packages/pdf) — PDF output
- [`poppler-utils`](https://poppler.freedesktop.org/) — SVG and PNG conversion (system dependency, optional)

## License

MIT
