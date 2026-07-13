defmodule SwissQrBill.Output.PdfOutput do
  @moduledoc """
  Generates the complete Swiss QR bill payment part as PDF.
  Uses the `pdf` library. Layout matches the SIX style guide.
  The QR code is drawn directly as filled rectangles from the QR matrix.

  Long values (e.g. a long creditor name or street) are wrapped to the width of
  their column via `Pdf.text_wrap/5`, so they never overrun into the QR code
  (receipt) or off the page edge (payment part). Each information section is
  laid out against the page cursor: `text_wrap` advances the cursor to the
  bottom of the wrapped block, and the next field starts from there. Very long
  unbreakable tokens are soft-broken so they wrap mid-word instead of
  overrunning.

  Font sizes follow the SIX style guide per section (§3.4): the receipt uses
  6 pt headings / 8 pt values, the payment part 8 pt headings / 10 pt values,
  and the title 11 pt.
  """

  alias SwissQrBill.{
    Address,
    CreditorInformation,
    PaymentAmount,
    PaymentReference,
    AdditionalInformation
  }

  alias SwissQrBill.QrCode.QrCode, as: QrGen
  alias SwissQrBill.QrCodeData
  alias SwissQrBill.Output.Translation

  # Dimensions in mm, converted to points for PDF (1mm = 2.8346pt)
  @mm 2.8346
  @receipt_width 62
  @total_width 210
  @total_height 105

  # Font sizes per SIX IG QR-bill §3.4. Payment part: headings/values 6–10pt
  # (recommended 8/10). Receipt: 6pt headings, 8pt values. Title: 11pt.
  @title_font_size 11
  @payment_heading_size 8
  @payment_value_size 10
  @receipt_heading_size 6
  @receipt_value_size 8
  @branding_font_size 6
  # Vertical gap between a value baseline and its heading baseline (4 mm).
  @heading_gap 4.0 * 2.8346

  # Line spacing for the wrapped information sections. The receipt is tighter so
  # it fits its small vertical budget at 8pt; the payment part has more room.
  @receipt_line_height 3.2 * 2.8346
  @payment_line_height 4.0 * 2.8346

  # Usable text width of each information column (points).
  # Receipt: x=5mm to ~5mm before the 62mm perforation. Payment part: from the
  # text start to the 5mm right margin.
  @receipt_text_width 52 * 2.8346

  # text_wrap only breaks on whitespace/hyphens, so a very long unbreakable
  # token (e.g. a German compound name) would overrun. We insert soft hyphens
  # (U+00AD) into tokens longer than this, so they can wrap mid-word when a
  # column is too narrow — and stay intact when it is not. The wrapper drops
  # unused soft hyphens and renders a hyphen at the break point. (A zero-width
  # space would seem more natural, but the pdf library byte-truncates U+200B
  # to 0x0B — an undefined glyph — whereas U+00AD is proper WinAnsi 0xAD.)
  @soft_hyphen <<0xAD::utf8>>
  @max_token_length 22

  # The pdf library renders text as WinAnsi (CP1252) and raises on anything
  # outside it, but the Swiss QR character set (§4.1.1) rightly includes all of
  # Latin Extended-A plus Ș ș Ț ț. For the *printed* text we transliterate the
  # codepoints WinAnsi cannot represent — NFD-decompose and strip combining
  # marks (Ș → S, ā → a) — while the QR payload keeps the original characters.
  # These letters have no decomposition and need an explicit mapping:
  @transliterations %{
    "Đ" => "D",
    "đ" => "d",
    "Ħ" => "H",
    "ħ" => "h",
    "ı" => "i",
    "Ĳ" => "IJ",
    "ĳ" => "ij",
    "ĸ" => "k",
    "Ŀ" => "L",
    "ŀ" => "l",
    "Ł" => "L",
    "ł" => "l",
    "ŉ" => "'n",
    "Ŋ" => "N",
    "ŋ" => "n",
    "Ŧ" => "T",
    "ŧ" => "t",
    "ſ" => "s"
  }

  @a4_height 297

  # Extra canvas below the QR code for the branding line (qr_code output only)
  @qr_branding_space 4

  # Internal — use SwissQrBill.to_pdf/2, which validates the bill first.
  # Rendering assumes validated input (field lengths, character set).
  @doc false
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(bill, opts \\ []) do
    language = Keyword.get(opts, :language, :de)
    output_size = Keyword.get(opts, :output_size, :payment_slip)
    branding = Keyword.get(opts, :branding, false)

    qr_data = QrCodeData.encode(bill)

    case QrGen.to_matrix(qr_data) do
      {:ok, matrix} ->
        # Safety net: any raise inside the Pdf GenServer (e.g. an unencodable
        # character that slipped past sanitize_text/1) surfaces to the caller
        # as an EXIT from GenServer.call — convert it to an error tuple
        # instead of taking the calling process down.
        try do
          {:ok, render_size(output_size, bill, matrix, language, branding)}
        rescue
          e -> {:error, "PDF rendering failed: #{Exception.message(e)}"}
        catch
          :exit, reason -> {:error, "PDF rendering failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp render_size(:qr_code, _bill, matrix, language, branding) do
    # QR code only: 46x46mm + 5mm padding each side = 56x56mm
    padding = 5
    qr_size = 46
    total = qr_size + padding * 2
    branding_space = if branding, do: @qr_branding_space, else: 0

    Pdf.build([size: [Pdf.mm(total), Pdf.mm(total + branding_space)]], fn pdf ->
      pdf
      |> Pdf.set_font("Helvetica", @payment_value_size)
      |> draw_qr_matrix(matrix, padding * @mm, (padding + branding_space) * @mm)
      |> draw_branding(branding, language, :qr_code)
      |> Pdf.export()
    end)
  end

  defp render_size(:a4, bill, matrix, language, branding) do
    Pdf.build([size: [Pdf.mm(@total_width), Pdf.mm(@a4_height)]], fn pdf ->
      # Payment slip sits at the bottom of A4
      # PDF coordinate system: origin at bottom-left
      # So offset_y = 0 places it at the bottom already
      pdf
      |> draw_separator()
      |> Pdf.set_font("Helvetica", @payment_value_size)
      |> draw_receipt(bill, language, 0)
      |> draw_payment_part(bill, matrix, language, 0)
      |> draw_separate_note(language)
      |> draw_branding(branding, language, :a4)
      |> Pdf.export()
    end)
  end

  defp render_size(:payment_slip, bill, matrix, language, branding) do
    Pdf.build([size: [Pdf.mm(@total_width), Pdf.mm(@total_height)]], fn pdf ->
      pdf
      |> draw_separator()
      |> Pdf.set_font("Helvetica", @payment_value_size)
      |> draw_receipt(bill, language, 0)
      |> draw_payment_part(bill, matrix, language, 0)
      |> draw_branding(branding, language, :payment_slip)
      |> Pdf.export()
    end)
  end

  # "Separate before paying in" — required above the payment part when the
  # QR-bill is delivered as a PDF / printed on non-perforated paper, which is
  # exactly the :a4 case. Centered directly above the slip's top edge.
  defp draw_separate_note(pdf, lang) do
    pdf
    |> Pdf.set_font("Helvetica", @payment_heading_size)
    |> Pdf.text_wrap!(
      {0, (@total_height + 4) * @mm},
      {@total_width * @mm, 4 * @mm},
      Translation.get(:separate, lang),
      align: :center
    )
    |> Pdf.set_font("Helvetica", @payment_value_size)
  end

  defp draw_branding(pdf, false, _lang, _placement), do: pdf

  # The style guide permits no additional content inside the standardized
  # 210x105 mm payment part, so branding is only drawn where there is canvas
  # outside it: above the slip (:a4) or on the extra strip (:qr_code).
  defp draw_branding(pdf, true, _lang, :payment_slip), do: pdf

  defp draw_branding(pdf, true, lang, placement) do
    text = Translation.get(:branding, lang)

    pdf
    |> Pdf.set_font("Helvetica", @branding_font_size)
    |> Pdf.set_fill_color(:gray)
    |> draw_branding_text(text, placement)
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", @payment_value_size)
  end

  # Centered above the payment slip's top edge, one band above the
  # "Separate before paying in" note — outside the standardized payment part,
  # so the slip itself stays untouched.
  defp draw_branding_text(pdf, text, :a4) do
    Pdf.text_wrap!(
      pdf,
      {0, (@total_height + 8) * @mm},
      {@total_width * @mm, 4 * @mm},
      text,
      align: :center
    )
  end

  # Centered in the extra canvas strip below the QR code.
  defp draw_branding_text(pdf, text, :qr_code) do
    Pdf.text_wrap!(
      pdf,
      {0, (@qr_branding_space + 0.5) * @mm},
      {56 * @mm, 4 * @mm},
      text,
      align: :center
    )
  end

  defp draw_separator(pdf) do
    x = @receipt_width * @mm

    pdf
    |> Pdf.set_line_width(0.5)
    |> Pdf.set_stroke_color(:black)
    |> draw_dashed_line({x, @total_height * @mm}, {x, 0}, 2, 2)
  end

  defp draw_receipt(pdf, bill, lang, _offset_y) do
    x = 5 * @mm
    page_top = @total_height * @mm
    y = page_top - 5 * @mm

    pdf
    # Title
    |> Pdf.set_font("Helvetica", @title_font_size, bold: true)
    |> Pdf.text_at({x, y}, Translation.get(:receipt, lang))
    # Information section flows from the cursor downward
    |> Pdf.set_cursor(y - 12 * @mm)
    |> draw_receipt_sections(bill, lang, x)
  end

  defp draw_receipt_sections(pdf, bill, lang, x) do
    max_w = @receipt_text_width
    h = @receipt_heading_size
    v = @receipt_value_size
    lh = @receipt_line_height

    # Creditor
    pdf =
      draw_field(pdf, x, max_w, Translation.get(:creditor, lang), creditor_text(bill), h, v, lh)

    # Reference
    pdf =
      case bill.payment_reference do
        %PaymentReference{type: :non} ->
          pdf

        %PaymentReference{} = pr ->
          ref_text = PaymentReference.formatted_reference(pr) || ""
          draw_field(pdf, x, max_w, Translation.get(:reference, lang), ref_text, h, v, lh)
      end

    # Payable by
    pdf =
      case bill.debtor do
        nil ->
          pdf = draw_label(pdf, x, max_w, Translation.get(:payable_by_name, lang), h, lh)
          top = Pdf.cursor(pdf)
          draw_corner_marks(pdf, x, top - 20 * @mm, 52 * @mm, 20 * @mm)

        %Address{} = addr ->
          draw_field(
            pdf,
            x,
            max_w,
            Translation.get(:payable_by, lang),
            Address.full_address(addr),
            h,
            v,
            lh
          )
      end

    # Currency and amount (fixed position)
    currency_y = 23 * @mm

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", h, bold: true)
      |> Pdf.text_at({x, currency_y + @heading_gap}, Translation.get(:currency, lang))
      |> Pdf.set_font("Helvetica", v)
      |> Pdf.text_at({x, currency_y}, sanitize_text(bill.payment_amount.currency))

    amount_x = x + 18 * @mm

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", h, bold: true)
      |> Pdf.text_at({amount_x, currency_y + @heading_gap}, Translation.get(:amount, lang))
      |> Pdf.set_font("Helvetica", v)

    pdf =
      case PaymentAmount.formatted_amount(bill.payment_amount) do
        "" -> draw_corner_marks(pdf, amount_x, currency_y - 2 * @mm, 30 * @mm, 10 * @mm)
        formatted -> Pdf.text_at(pdf, {amount_x, currency_y}, formatted)
      end

    # Acceptance point — right-aligned to the receipt's text edge (57 mm)
    # per the style guide, so the right edge is stable across languages.
    ap_y = 10 * @mm

    pdf
    |> Pdf.set_font("Helvetica", h, bold: true)
    |> Pdf.text_wrap!(
      {x, ap_y + 2 * @mm},
      {@receipt_text_width, 4 * @mm},
      Translation.get(:acceptance_point, lang),
      align: :right
    )
  end

  defp draw_payment_part(pdf, bill, matrix, lang, _offset_y) do
    x = (@receipt_width + 5) * @mm
    page_top = @total_height * @mm
    y = page_top - 5 * @mm

    pdf
    # Title
    |> Pdf.set_font("Helvetica", @title_font_size, bold: true)
    |> Pdf.text_at({x, y}, Translation.get(:payment_part, lang))
    # QR Code
    |> draw_qr_matrix(matrix, x, y - 12 * @mm - 46 * @mm)
    # Currency and amount — same height as receipt (23mm from bottom)
    |> draw_payment_amount(bill, lang, x, 23 * @mm)
    # Right side text (information section), flowing from the cursor downward
    |> Pdf.set_cursor(y - 10 * @mm)
    |> draw_payment_text(bill, lang, (@receipt_width + 56) * @mm)
  end

  defp draw_qr_matrix(pdf, matrix, x, y) do
    # matrix is a list of lists (rows), each element is 0 or 1
    # QR code should be 46x46mm
    rows = length(matrix)
    module_size = 46 * @mm / rows

    pdf = Pdf.set_fill_color(pdf, :black)

    matrix
    |> Enum.with_index()
    |> Enum.reduce(pdf, fn {row, row_idx}, pdf_acc ->
      row
      |> Enum.with_index()
      |> Enum.reduce(pdf_acc, fn {cell, col_idx}, inner_pdf ->
        if cell == 1 do
          px = x + col_idx * module_size
          py = y + (rows - 1 - row_idx) * module_size

          inner_pdf
          |> Pdf.rectangle({px, py}, {module_size, module_size})
          |> Pdf.fill()
        else
          inner_pdf
        end
      end)
    end)
    |> draw_swiss_cross(x, y, 46 * @mm)
    |> Pdf.set_fill_color(:black)
  end

  defp draw_swiss_cross(pdf, qr_x, qr_y, qr_size) do
    # Swiss cross: centered, 7x7mm total per the style guide — no extra
    # cleared border (the ECC-M redundancy covers the logo area).
    cross_size = 7 * @mm
    cx = qr_x + (qr_size - cross_size) / 2
    cy = qr_y + (qr_size - cross_size) / 2

    pdf
    # Black square
    |> Pdf.set_fill_color(:black)
    |> Pdf.rectangle({cx, cy}, {cross_size, cross_size})
    |> Pdf.fill()
    # White cross (vertical bar) — Swiss cross grid: 6/32 arm width, 20/32 arm length
    |> Pdf.set_fill_color(:white)
    |> Pdf.rectangle(
      {cx + cross_size * 13 / 32, cy + cross_size * 6 / 32},
      {cross_size * 6 / 32, cross_size * 20 / 32}
    )
    |> Pdf.fill()
    # White cross (horizontal bar)
    |> Pdf.rectangle(
      {cx + cross_size * 6 / 32, cy + cross_size * 13 / 32},
      {cross_size * 20 / 32, cross_size * 6 / 32}
    )
    |> Pdf.fill()
  end

  defp draw_payment_amount(pdf, bill, lang, x, y) do
    pdf
    |> Pdf.set_font("Helvetica", @payment_heading_size, bold: true)
    |> Pdf.text_at({x, y + @heading_gap}, Translation.get(:currency, lang))
    |> Pdf.set_font("Helvetica", @payment_value_size)
    |> Pdf.text_at({x, y}, sanitize_text(bill.payment_amount.currency))
    |> Pdf.set_font("Helvetica", @payment_heading_size, bold: true)
    |> Pdf.text_at({x + 18 * @mm, y + @heading_gap}, Translation.get(:amount, lang))
    |> Pdf.set_font("Helvetica", @payment_value_size)
    |> then(fn pdf ->
      case PaymentAmount.formatted_amount(bill.payment_amount) do
        # Blank amount box on the payment part: 40 x 15 mm per the style
        # guide (the 30 x 10 mm box is receipt-only). Top edge 2 mm below
        # the "Amount" heading baseline.
        "" -> draw_corner_marks(pdf, x + 18 * @mm, y - 13 * @mm, 40 * @mm, 15 * @mm)
        formatted -> Pdf.text_at(pdf, {x + 18 * @mm, y}, formatted)
      end
    end)
  end

  defp draw_payment_text(pdf, bill, lang, text_x) do
    max_w = (@total_width - 5) * @mm - text_x
    h = @payment_heading_size
    v = @payment_value_size
    lh = @payment_line_height

    # Creditor
    pdf =
      draw_field(
        pdf,
        text_x,
        max_w,
        Translation.get(:creditor, lang),
        creditor_text(bill),
        h,
        v,
        lh
      )

    # Reference
    pdf =
      case bill.payment_reference do
        %PaymentReference{type: :non} ->
          pdf

        %PaymentReference{} = pr ->
          ref_text = PaymentReference.formatted_reference(pr) || ""
          draw_field(pdf, text_x, max_w, Translation.get(:reference, lang), ref_text, h, v, lh)
      end

    # Additional information
    pdf =
      case bill.additional_information do
        nil ->
          pdf

        %AdditionalInformation{} = ai ->
          case AdditionalInformation.formatted_string(ai) do
            "" ->
              pdf

            text ->
              draw_field(
                pdf,
                text_x,
                max_w,
                Translation.get(:additional_information, lang),
                text,
                h,
                v,
                lh
              )
          end
      end

    # Payable by
    case bill.debtor do
      nil ->
        pdf = draw_label(pdf, text_x, max_w, Translation.get(:payable_by_name, lang), h, lh)
        top = Pdf.cursor(pdf)
        draw_corner_marks(pdf, text_x, top - 25 * @mm, 65 * @mm, 25 * @mm)

      %Address{} = addr ->
        draw_field(
          pdf,
          text_x,
          max_w,
          Translation.get(:payable_by, lang),
          Address.full_address(addr),
          h,
          v,
          lh
        )
    end
  end

  # Draws a bold heading followed by its (wrapped) value, starting at the page
  # cursor, then leaves a 2mm gap before the next field. The cursor ends just
  # below the field.
  defp draw_field(pdf, x, max_w, heading, value, heading_size, value_size, leading) do
    pdf
    |> draw_label(x, max_w, heading, heading_size, leading)
    |> Pdf.set_font("Helvetica", value_size)
    |> wrap_at_cursor(x, max_w, value, leading)
    |> Pdf.move_down(2 * @mm)
  end

  # Draws a bold heading at the cursor.
  defp draw_label(pdf, x, max_w, label, size, leading) do
    pdf
    |> Pdf.set_font("Helvetica", size, bold: true)
    |> wrap_at_cursor(x, max_w, label, leading)
  end

  # Wraps `text` to `max_w` at the current cursor using the current font, and
  # advances the cursor to the bottom of the rendered block. Wrapping is
  # measured against the font actually embedded in the PDF, so break points are
  # deterministic; `leading` pins line spacing regardless of font.
  defp wrap_at_cursor(pdf, _x, _max_w, "", _leading), do: pdf

  defp wrap_at_cursor(pdf, x, max_w, text, leading) do
    top = Pdf.cursor(pdf)
    # height = distance to the page bottom: generous, so all lines render.
    {pdf, _result} =
      Pdf.text_wrap(pdf, {x, top}, {max_w, top}, text |> sanitize_text() |> soft_break(),
        leading: leading,
        align: :left
      )

    pdf
  end

  # Transliterates codepoints the pdf library's WinAnsi encoding cannot
  # represent, so a validated bill (full §4.1.1 charset) always renders instead
  # of crashing the Pdf process. Also doubles backslashes: the pdf library
  # escapes parentheses in PDF string literals but not the escape character
  # itself, so a lone backslash would corrupt the content stream. Applied only
  # to printed text; the QR payload keeps the original characters.
  # Public for testing.
  @doc false
  def sanitize_text(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.codepoints()
    |> Enum.map_join(&sanitize_codepoint/1)
  end

  defp sanitize_codepoint(cp) do
    cond do
      winansi?(cp) -> cp
      mapped = @transliterations[cp] -> mapped
      true -> strip_diacritics(cp)
    end
  end

  defp strip_diacritics(cp) do
    base =
      cp
      |> String.normalize(:nfd)
      |> String.replace(~r/\p{Mn}/u, "")

    if base != "" and winansi?(base), do: base, else: "?"
  end

  defp winansi?(cp), do: Pdf.Encoding.WinAnsi.encode(cp, "") != ""

  # Inserts soft hyphens into over-long tokens so the wrapper can break them
  # mid-word when a column is too narrow. Unused soft hyphens are dropped by
  # the wrapper; a used one renders as a hyphen at the break point. Tokens
  # that fit are left untouched. Public for testing.
  @doc false
  def soft_break(text) do
    text
    |> String.split(" ")
    |> Enum.map_join(" ", &break_token/1)
  end

  defp break_token(token) do
    if String.length(token) > @max_token_length do
      token
      |> String.graphemes()
      |> Enum.chunk_every(@max_token_length)
      |> Enum.map_join(@soft_hyphen, &Enum.join/1)
    else
      token
    end
  end

  defp draw_corner_marks(pdf, x, y, width, height) do
    corner = 3 * @mm

    pdf
    |> Pdf.set_line_width(0.75)
    |> Pdf.set_stroke_color(:black)
    # Bottom-left
    |> Pdf.line({x, y + corner}, {x, y})
    |> Pdf.line({x, y}, {x + corner, y})
    # Bottom-right
    |> Pdf.line({x + width - corner, y}, {x + width, y})
    |> Pdf.line({x + width, y}, {x + width, y + corner})
    # Top-left
    |> Pdf.line({x, y + height - corner}, {x, y + height})
    |> Pdf.line({x, y + height}, {x + corner, y + height})
    # Top-right
    |> Pdf.line({x + width - corner, y + height}, {x + width, y + height})
    |> Pdf.line({x + width, y + height}, {x + width, y + height - corner})
    |> Pdf.stroke()
  end

  defp draw_dashed_line(pdf, {x1, y1}, {x2, y2}, dash_len, gap_len) do
    # Draw a dashed vertical line — draw all segments first, stroke once
    total_length = abs(y1 - y2)
    segment = (dash_len + gap_len) * @mm
    num_segments = trunc(total_length / segment)

    pdf =
      Enum.reduce(0..num_segments, pdf, fn i, pdf_acc ->
        start_y = y1 - i * segment
        end_y = max(start_y - dash_len * @mm, y2)

        if start_y > y2 do
          Pdf.line(pdf_acc, {x1, start_y}, {x2, end_y})
        else
          pdf_acc
        end
      end)

    Pdf.stroke(pdf)
  end

  defp creditor_text(bill) do
    iban = CreditorInformation.formatted_iban(bill.creditor_information)
    address = Address.full_address(bill.creditor)
    "#{iban}\n#{address}"
  end
end
