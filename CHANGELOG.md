# Changelog

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
