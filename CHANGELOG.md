# Changelog

## v0.2.0

This release updates the library to the **SIX Implementation Guidelines for the QR-bill v2.4**, stores monetary amounts as `Decimal`, and tightens validation to match the standard. It contains **breaking changes** — see below.

### ⚠️ Breaking changes

- **Amounts are now `Decimal` instead of `float`.** `SwissQrBill.set_payment_amount/3` and `SwissQrBill.PaymentAmount.new/2` now accept a `Decimal`, a number (integer or float), or a decimal string. The stored `payment_amount.amount` field is now a `%Decimal{}`. Existing float / integer / `nil` inputs keep working and the generated QR and print output is byte-identical — only code that *reads* `payment_amount.amount` back (expecting a float) needs to adapt. Adds a `decimal ~> 3.1` dependency.
- **Stricter validation may reject bills that previously passed:**
  - The Swiss QR character set (§4.1.1) is now enforced on all text fields. Characters outside the permitted set (e.g. emoji) are rejected instead of being silently written into the QR payload.
  - The combined length of the unstructured message and the billing information is now capped at 140 characters (§4.3.3), in addition to the existing 140-character limit on each field individually.
  - The minimum amount is now 0.01 (was 0).
- **French and Italian "payment part" headings corrected** to the official short forms — "Section paiement" (was "Section de paiement") and "Sezione pagamento" (was "Sezione di pagamento"). This changes the rendered output.

### Changed

- **Updated to SIX IG QR-bill v2.4** (from v2.3). For invoicing in CHF there is no technical change. For EUR, the QR-IBAN / QR-reference (QRR) combination is no longer permitted — EUR invoices must use a regular IBAN with a Creditor Reference (SCOR) or no reference (NON). v2.3 remains valid in parallel until November 2027.
- **Corrected the Romansh (`:rm`) translations** to match the official multilingual glossary (Annex C, Table 23) — e.g. `currency` "Valuta" (was "Munaida"), `receipt` "Quittanza" (was "Attest da recepziun"), `acceptance_point` "Post da recepziun".
- Completed the permitted character set to include `Ș ș Ț ț` (U+0218–U+021B) and `€` (U+20AC), per §4.1.1.

### Added

- **`SwissQrBill.Validation.warnings/1`** — returns non-blocking advisories that do not affect validity. Currently flags the QR-IBAN/QRR + EUR combination (reserved for CHF under v2.4; rejected once euroSIC is discontinued, by November 2027). These warnings are also emitted via `Logger` during validation.
- **"Separate before paying in" note on `:a4` output** — the localized note is now rendered centered above the payment part, as the guidelines require for QR-bills delivered as PDF / printed on non-perforated paper.
- **QR payload size guard** — a payload that would need a QR version above 25 (the maximum the Swiss standard permits) is now rejected with `{:error, _}` instead of silently producing an oversized, possibly unscannable symbol. Reachable only with diacritic-heavy, near-maximum-length bills.

### Fixed (comprehensive audit)

Results of a security/reliability/conformance audit of the rendering pipeline:

- **Names with Latin Extended-A characters no longer crash rendering.** The `pdf` library encodes text as WinAnsi and raised (killing its process) on characters like `Ș`, `Ł`, or `Ā` — all of which the Swiss QR character set explicitly permits and validation rightly accepted. Printed text is now transliterated (`Ștefan` → `Stefan`, `Łukasz` → `Lukasz`); the QR payload keeps the original characters. A safety net additionally converts any residual rendering raise/exit into `{:error, _}`.
- **Soft-wrapped long tokens no longer render a stray undefined glyph.** The mid-word break marker (U+200B) was byte-truncated to `0x0B` by the PDF encoding, leaving an artifact inside every wrapped long word. Breaks now use soft hyphens (U+00AD): invisible when unused, a proper hyphen at the break point.
- **`validate/1` never raises.** Previously it crashed on `"NaN"` amounts (`Decimal.parse` accepts NaN; `Decimal.compare` raises on it), unknown reference-type atoms (e.g. `:cor`), and various wrong-typed struct fields. All of these are now reported as validation errors. `PaymentReference.new/2` also rejects unknown types at construction.
- **Backslashes in names no longer corrupt the PDF.** The PDF string escape in the `pdf` library covers parentheses but not the escape character itself; a name ending in `\` produced an unterminated string literal. Backslashes are now escaped before rendering.
- **Blank-amount box on the payment part corrected to 40 x 15 mm** (was receipt-sized 30 x 10 mm) per the style guide.
- **Branding is no longer drawn inside the standardized payment part.** The style guide permits no additional content within the 210 x 105 mm slip, so `branding: true` is now skipped for `:payment_slip` (unchanged for `:a4` and `:qr_code`; the `:a4` line moved up to make room for the "Separate before paying in" note).
- **Swiss cross corrected to 7 x 7 mm total** — the extra 1 mm cleared border around it was removed.
- **"Acceptance point" is right-aligned** to the receipt's text edge (57 mm), so its right edge is stable across languages.
- Constructors coerce plausible integer inputs (postal code, building number, 27-digit reference) and report — rather than crash on — wrong-typed currency, country, or IBAN values.

### Security

- **Conversion hardening:** `to_png/2` now bounds `:dpi` to 36–2400 (an unbounded value could make poppler allocate an OOM-scale bitmap) and both `to_svg/2`/`to_png/2` run `pdftocairo` under a 30-second timeout, returning `{:error, _}` instead of blocking the caller indefinitely. A missing `pdftocairo` binary is reported as an error instead of raising.
- **Temp-file privacy:** the intermediate PDF for SVG/PNG conversion (which contains the payment data) is now written inside a per-call `0700` directory instead of world-readable in `/tmp`.

### Dependencies

- Added `decimal ~> 3.1` (pinned to the 3.x line; the 2.x line carries a published security advisory).
- Verified against the latest releases of `pdf` (0.8), `qr_code` (3.2), and `ex_doc` (0.40).

## v0.1.4

### Fixed

- **Long names and addresses no longer collide with the QR code or run off the page edge.** Values in the information sections (creditor, debtor, reference, additional information) are now wrapped to the width of their column instead of being drawn on a single unbounded line. A long creditor or debtor name or street — long but within the 70-character limit — now wraps onto multiple lines, as the SIX Implementation Guidelines permit (§3.5.4 / §3.6.2). Very long unbreakable tokens (e.g. German compound names) are soft-broken so they wrap mid-word rather than overrunning. Reported by [@jueberschlag](https://github.com/jueberschlag) in [#1](https://github.com/e9li/swiss_qr_bill/issues/1).

### Changed

- **Font sizes now follow the SIX style guide per section** (§3.4): the receipt uses 6 pt headings / 8 pt values (was 8 pt / 9 pt), and the payment part uses 8 pt headings / 10 pt values (was 8 pt / 9 pt). The receipt uses tighter line spacing to fit its smaller area. The rendered appearance of the receipt and payment part therefore changes; the encoded QR data is unchanged.
- Regenerated the `samples/` files with the updated layout.

The public API and options are unchanged — only the rendered layout differs.

## v0.1.3

### Changed

- Verified compatibility with **Elixir 1.20 / OTP 29** — the library compiles cleanly with no errors or warnings (`mix compile --warnings-as-errors --all-warnings`).
- Removed a redundant `is_binary/1` guard in the translation test that Elixir 1.20's type checker flagged as always-true.

No public API or behavior changes — this release is fully backward compatible.

## v0.1.2

### Added

- **Branding option** — new `branding: true` option on `to_pdf/2`, `to_svg/2`, and `to_png/2` (default: `false`). Adds a small gray "Created by qrbill.dev" line, localized to the bill's `:language` (de: "Erstellt mit qrbill.dev", fr: "Créé avec qrbill.dev", it: "Creato con qrbill.dev", rm: "Creà cun qrbill.dev"). Placement by `:output_size`:
  - `:a4` — centered just above the payment slip's top edge (outside the standardized payment part)
  - `:payment_slip` — small text at the bottom-right edge of the payment part
  - `:qr_code` — below the QR code; the canvas grows by 4 mm (56 x 60 mm) to fit the line
- New `:branding` translation key in `SwissQrBill.Output.Translation`

Output without `branding` is unchanged.

## v0.1.1

### Added

- **SVG output** (`to_svg/2`) — generates SVG with all text converted to glyph outlines (paths) via `pdftocairo`, ensuring identical rendering on all devices without font dependencies
- **PNG output** (`to_png/2`) — rasterizes the PDF at configurable DPI (default: 300) via `pdftocairo`
- **Output sizes** — new `:output_size` option for all formats:
  - `:payment_slip` (210 x 105 mm, default)
  - `:a4` (210 x 297 mm, payment slip at bottom)
  - `:qr_code` (56 x 56 mm, QR code only)
- **Romansh language** (`:rm`) — fifth official Swiss language added to translations
- **IBAN utilities** — `SwissQrBill.IBAN.validate/1`, `format/1`, `qr_iban?/1`, `normalize/1`
- Comprehensive test suite (170 tests, 93% coverage)

### Changed

- Updated README with full documentation of all features, output formats, and validation constraints

## v0.1.0

- Initial release
- PDF output with complete payment part (receipt + payment part) per SIX v2.3
- QR reference (QRR) and creditor reference (SCOR) generators
- Full validation of IBAN, references, addresses, and character sets
- Support for German, French, Italian, and English
