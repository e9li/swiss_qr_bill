# SwissQrBill

Swiss QR-bill generation library for Elixir, implementing the [SIX QR-bill standard (v2.3)](https://www.six-group.com/dam/download/banking-services/standardization/qr-bill/ig-qr-bill-v2.3-en.pdf).

Generates the complete payment part (Zahlteil) with receipt as PDF, ready for printing or embedding in invoices.

## Issues & Feedback

This library is developed at [git.e9li.com](https://git.e9li.como/e9li/swiss_qr_bill) and mirrored to [GitHub](https://github.com/e9li/swiss_qr_bill).<br>
If you found a bug or have a suggestion, you can either:

- Open an issue on [GitHub](https://github.com/e9li/swiss_qr_bill/issues)
- Send an email to rafael@e9li.com


## Installation

Add `swiss_qr_bill` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:swiss_qr_bill, "~> 0.1.0"}
  ]
end
```

## Usage

### Building a QR bill

```elixir
# Create addresses
creditor = SwissQrBill.Address.new("Muster AG", "Bahnhofstrasse", "1", "8001", "Zurich", "CH")
debtor = SwissQrBill.Address.new("Max Muster", "Hauptstrasse", "42", "3000", "Bern", "CH")

# Address without street (minimal form)
creditor = SwissQrBill.Address.new("Muster AG", "8001", "Zurich", "CH")

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
File.write("qr_bill.pdf", pdf_binary)
```

### Languages

The `:language` option supports `:de`, `:fr`, `:it`, `:en`, and `:rm` (Romansh). Defaults to `:de`.

```elixir
{:ok, pdf_binary} = SwissQrBill.to_pdf(bill, language: :fr)
```

## Reference generators

### QR reference (QRR)

Used with QR-IBANs (IID 30000-31999). Generates a 27-digit reference with mod-10 check digit.

```elixir
{:ok, ref} = SwissQrBill.Reference.QrReferenceGenerator.generate("210000", "313947143000901")
#=> {:ok, "210000000003139471430009017"}
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
  |> SwissQrBill.set_creditor(SwissQrBill.Address.new("Muster AG", "8001", "Zurich", "CH"))
  |> SwissQrBill.set_creditor_information("CH93 0076 2011 6238 5295 7")
  |> SwissQrBill.set_payment_amount("CHF")
  |> SwissQrBill.set_payment_reference(:non)

{:ok, pdf} = SwissQrBill.to_pdf(bill)
```

When amount or debtor are omitted, placeholder corner marks are rendered per the SIX style guide.

## Output layout

The PDF output renders the complete payment part (210 x 105 mm):

- **Receipt** (left, 62 mm) — creditor, reference, amount, acceptance point
- **Payment part** (right, 148 mm) — QR code with Swiss cross, creditor, reference, additional information, amount, debtor

The layout follows the SIX style guide specifications.

## Dependencies

- [`qr_code`](https://hex.pm/packages/qr_code) — QR code generation
- [`pdf`](https://hex.pm/packages/pdf) — PDF output

## License

MIT
