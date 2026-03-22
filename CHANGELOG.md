# Changelog

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
