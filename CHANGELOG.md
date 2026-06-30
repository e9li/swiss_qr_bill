# Changelog

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
