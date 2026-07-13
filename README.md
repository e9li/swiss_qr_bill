# SwissQrBill

Swiss QR-bill generation library for Elixir, implementing the [SIX QR-bill standard (v2.4)](https://www.six-group.com/dam/download/banking-services/standardization/qr-bill/ig-qr-bill-v2.4-en.pdf) — also conformant to v2.3, which remains valid in parallel until November 2027.

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
    {:swiss_qr_bill, "~> 0.2.0"}
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

> **Amounts** can be a `Decimal`, a number, or a decimal string — e.g. `set_payment_amount("CHF", 2500.25)`, `set_payment_amount("CHF", "2500.25")`, or `set_payment_amount("CHF", Decimal.new("2500.25"))`. They are stored as `Decimal` internally and rounded to two decimal places, so there are no floating-point rounding surprises.

### Validation

```elixir
{:ok, bill} = SwissQrBill.validate(bill)
# or
{:error, errors} = SwissQrBill.validate(invalid_bill)
# errors is a list of descriptive strings
```

Validates IBAN format, QR-IBAN/reference-type compatibility, address fields, the Swiss QR character set, amount range, and field lengths (including the combined 140-character limit on message + billing information).

#### Warnings (non-blocking)

`SwissQrBill.Validation.warnings/1` returns advisory messages that do **not** affect validity (they are also logged via `Logger`). Currently it flags using a QR-IBAN / QR-reference with an **EUR** amount: under v2.4 that combination is reserved for CHF, and it becomes invalid once euroSIC is discontinued (EUR QR-bills move to SEPA Credit Transfer by November 2027 at the latest).

```elixir
SwissQrBill.Validation.warnings(bill)
#=> [] for a valid combination, or a list of advisory strings
```

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
The `:dpi` option accepts integers between 36 and 2400 (default: 300).

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

For `:a4`, the localized note *"Separate before paying in"* is rendered
centered above the payment part, as the guidelines require for QR-bills
delivered as PDF or printed on non-perforated paper.

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

### Branding

All three formats accept the `:branding` option. When `true`, a small gray
"Created by qrbill.dev" line is added, localized to the bill's `:language`.
Defaults to `false`, and output without it is unchanged.

Because the style guide permits no additional content inside the standardized
210 x 105 mm payment part, branding is only drawn for `:a4` (above the slip)
and `:qr_code` (on an extra strip below the code) — it is skipped for
`:payment_slip`.

```elixir
{:ok, pdf} = SwissQrBill.to_pdf(bill, branding: true)
{:ok, svg} = SwissQrBill.to_svg(bill, branding: true)
{:ok, png} = SwissQrBill.to_png(bill, branding: true, dpi: 300)
```

The localized text is:

| Code | Text |
|------|------|
| `:de` | Erstellt mit qrbill.dev |
| `:fr` | Créé avec qrbill.dev |
| `:it` | Creato con qrbill.dev |
| `:en` | Created by qrbill.dev |
| `:rm` | Creà cun qrbill.dev |

Placement depends on the `:output_size`:

| Output size | Placement |
|-------------|-----------|
| `:a4` | Centered above the payment slip's top edge, above the "Separate before paying in" note |
| `:qr_code` | Below the QR code; the canvas grows by 4 mm (56 x 60 mm) to fit the line |
| `:payment_slip` | Not drawn (no canvas outside the standardized payment part) |

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

| IBAN type  | Allowed reference types | Currency |
|------------|------------------------|----------|
| QR-IBAN    | `:qrr` only            | CHF only (v2.4) |
| Regular    | `:scor` or `:non`      | CHF or EUR |

QR-IBANs are identified by their IID (positions 5-9) being in the range 30000-31999.

Under SIX IG v2.4 the QR-IBAN / QR-reference combination is reserved for CHF; for EUR use a regular IBAN with `:scor` or `:non`. `validate/1` still accepts QR-IBAN + EUR today and emits a non-blocking warning (see [Warnings](#warnings-non-blocking)) — this becomes a hard error once euroSIC is discontinued (~November 2027).

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

Font sizes follow the style guide per section: the receipt uses 6 pt headings and
8 pt values, and the payment part uses 8 pt headings and 10 pt values (the title is
11 pt). Sample outputs for all three sizes and formats are in [`samples/`](https://github.com/e9li/swiss_qr_bill/tree/main/samples).

### Long values

Long values wrap automatically to the width of their column. A long creditor or
debtor name or street (within the 70-character limit) breaks onto multiple lines
rather than overrunning into the QR code or off the page edge, as permitted by the
SIX Implementation Guidelines. Very long unbreakable words are broken mid-word only
where a line would otherwise overflow.

## Validation constraints

| Field | Constraint |
|-------|-----------|
| Amount | 0.01 to 999,999,999.99 |
| Currency | CHF or EUR |
| Creditor name | Max 70 characters |
| Creditor street | Max 70 characters |
| Building number | Max 16 characters |
| Postal code | Max 16 characters |
| City | Max 35 characters |
| Country | 2-letter ISO code |
| Message | Max 140 characters |
| Bill information | Max 140 characters |
| Message + bill information | Max 140 characters combined |
| Text fields | Swiss QR character set (Latin + `Ș ș Ț ț €`) |
| Alt. scheme parameter | Max 100 characters |
| Alternative schemes | Max 2 |
| IBAN | CH or LI, 21 characters |
| QRR reference | 27 digits, valid mod-10 |
| SCOR reference | RF + check digits + 1-21 alphanumeric |
| QR payload | Must fit QR version 25 (rejected as `{:error, _}` if larger) |

`validate/1` reports problems as a list of descriptive strings and never
raises, regardless of what the struct fields contain.

### Character set and printed text

The QR payload accepts the full Swiss QR character set (§4.1.1): Basic Latin,
Latin-1 Supplement, Latin Extended-A, `Ș ș Ț ț`, and `€`. The *printed* text
on the payment part is transliterated where the PDF font encoding (WinAnsi)
has no glyph — e.g. "Ștefan" prints as "Stefan", "Łukasz" as "Lukasz" — while
the QR code always carries the original characters.

The payment part uses Helvetica, which is not embedded in the PDF; viewers
and printers substitute a metrically compatible sans-serif (typically Arial,
Liberation Sans, or Nimbus Sans — the first two are on the style guide's
permitted list).

## Dependencies

- [`qr_code`](https://hex.pm/packages/qr_code) — QR code generation
- [`pdf`](https://hex.pm/packages/pdf) — PDF output
- [`decimal`](https://hex.pm/packages/decimal) — exact monetary amounts
- [`poppler-utils`](https://poppler.freedesktop.org/) — SVG and PNG conversion (system dependency, optional)

## License

MIT
