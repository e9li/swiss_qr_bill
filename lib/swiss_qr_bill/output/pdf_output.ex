defmodule SwissQrBill.Output.PdfOutput do
  @moduledoc """
  Generates the complete Swiss QR bill payment part as PDF.
  Uses the `pdf` library. Layout matches the SIX style guide.
  The QR code is drawn directly as filled rectangles from the QR matrix.
  """

  alias SwissQrBill.{Address, CreditorInformation, PaymentAmount, PaymentReference, AdditionalInformation}
  alias SwissQrBill.QrCode.QrCode, as: QrGen
  alias SwissQrBill.QrCodeData
  alias SwissQrBill.Output.Translation

  # Dimensions in mm, converted to points for PDF (1mm = 2.8346pt)
  @mm 2.8346
  @receipt_width 62
  @total_width 210
  @total_height 105

  @title_font_size 11
  @heading_font_size 8
  @value_font_size 9
  @line_height_pt 4.0 * 2.8346

  @doc """
  Generates the payment part as a PDF binary.
  The payment part is rendered at the bottom of an A4 page.
  """
  @spec render(map(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(bill, opts \\ []) do
    language = Keyword.get(opts, :language, :de)
    # Offset from bottom-left of A4 page — payment part sits at the bottom
    offset_y = 0

    qr_data = QrCodeData.encode(bill)

    case QrGen.to_matrix(qr_data) do
      {:ok, matrix} ->
        pdf_binary =
          Pdf.build([size: [Pdf.mm(@total_width), Pdf.mm(@total_height)]], fn pdf ->
            pdf
            |> draw_separator()
            |> Pdf.set_font("Helvetica", @value_font_size)
            |> draw_receipt(bill, language, offset_y)
            |> draw_payment_part(bill, matrix, language, offset_y)
            |> Pdf.export()
          end)

        {:ok, pdf_binary}

      {:error, reason} ->
        {:error, reason}
    end
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
    # Creditor
    |> then(&draw_receipt_sections(&1, bill, lang, x, y - 12 * @mm))
  end

  defp draw_receipt_sections(pdf, bill, lang, x, y) do
    # Creditor
    {pdf, y} = draw_heading_value(pdf, x, y, Translation.get(:creditor, lang), creditor_text(bill), 52)

    # Reference
    {pdf, y} =
      case bill.payment_reference do
        %PaymentReference{type: :non} ->
          {pdf, y}

        %PaymentReference{} = pr ->
          ref_text = PaymentReference.formatted_reference(pr) || ""
          draw_heading_value(pdf, x, y, Translation.get(:reference, lang), ref_text, 52)
      end

    # Payable by
    {pdf, _y} =
      case bill.debtor do
        nil ->
          {pdf, y} = draw_heading_value(pdf, x, y, Translation.get(:payable_by_name, lang), "", 52)
          {draw_corner_marks(pdf, x, y - 1 * @mm, 52 * @mm, 20 * @mm), y - 22 * @mm}

        %Address{} = addr ->
          draw_heading_value(pdf, x, y, Translation.get(:payable_by, lang), Address.full_address(addr), 52)
      end

    # Currency and amount
    currency_y = 23 * @mm
    pdf = pdf |> Pdf.set_font("Helvetica", @heading_font_size, bold: true)
    pdf = Pdf.text_at(pdf, {x, currency_y + @line_height_pt}, Translation.get(:currency, lang))
    pdf = pdf |> Pdf.set_font("Helvetica", @value_font_size)
    pdf = Pdf.text_at(pdf, {x, currency_y}, bill.payment_amount.currency)

    amount_x = x + 18 * @mm
    pdf = pdf |> Pdf.set_font("Helvetica", @heading_font_size, bold: true)
    pdf = Pdf.text_at(pdf, {amount_x, currency_y + @line_height_pt}, Translation.get(:amount, lang))
    pdf = pdf |> Pdf.set_font("Helvetica", @value_font_size)

    pdf =
      case PaymentAmount.formatted_amount(bill.payment_amount) do
        "" ->
          draw_corner_marks(pdf, amount_x, currency_y - 2 * @mm, 30 * @mm, 10 * @mm)

        formatted ->
          Pdf.text_at(pdf, {amount_x, currency_y}, formatted)
      end

    # Acceptance point
    ap_y = 10 * @mm

    pdf
    |> Pdf.set_font("Helvetica", @heading_font_size, bold: true)
    |> Pdf.text_at({x + 20 * @mm, ap_y}, Translation.get(:acceptance_point, lang))
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
    # Right side text
    |> draw_payment_text(bill, lang, (@receipt_width + 56) * @mm, y - 10 * @mm)
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
    # Swiss cross: centered, 7x7mm on a white background
    cross_size = 7 * @mm
    cx = qr_x + (qr_size - cross_size) / 2
    cy = qr_y + (qr_size - cross_size) / 2

    border = 1 * @mm

    pdf
    # White background with border
    |> Pdf.set_fill_color(:white)
    |> Pdf.rectangle({cx - border, cy - border}, {cross_size + 2 * border, cross_size + 2 * border})
    |> Pdf.fill()
    # Black square
    |> Pdf.set_fill_color(:black)
    |> Pdf.rectangle({cx, cy}, {cross_size, cross_size})
    |> Pdf.fill()
    # White cross (vertical bar) — Swiss cross grid: 6/32 arm width, 20/32 arm length
    |> Pdf.set_fill_color(:white)
    |> Pdf.rectangle({cx + cross_size * 13/32, cy + cross_size * 6/32}, {cross_size * 6/32, cross_size * 20/32})
    |> Pdf.fill()
    # White cross (horizontal bar)
    |> Pdf.rectangle({cx + cross_size * 6/32, cy + cross_size * 13/32}, {cross_size * 20/32, cross_size * 6/32})
    |> Pdf.fill()
  end

  defp draw_payment_amount(pdf, bill, lang, x, y) do
    pdf
    |> Pdf.set_font("Helvetica", @heading_font_size, bold: true)
    |> Pdf.text_at({x, y + @line_height_pt}, Translation.get(:currency, lang))
    |> Pdf.set_font("Helvetica", @value_font_size)
    |> Pdf.text_at({x, y}, bill.payment_amount.currency)
    |> Pdf.set_font("Helvetica", @heading_font_size, bold: true)
    |> Pdf.text_at({x + 18 * @mm, y + @line_height_pt}, Translation.get(:amount, lang))
    |> Pdf.set_font("Helvetica", @value_font_size)
    |> then(fn pdf ->
      case PaymentAmount.formatted_amount(bill.payment_amount) do
        "" -> draw_corner_marks(pdf, x + 18 * @mm, y - 3 * @mm, 30 * @mm, 10 * @mm)
        formatted -> Pdf.text_at(pdf, {x + 18 * @mm, y}, formatted)
      end
    end)
  end

  defp draw_payment_text(pdf, bill, lang, text_x, y) do
    # Creditor
    {pdf, y} = draw_heading_value(pdf, text_x, y, Translation.get(:creditor, lang), creditor_text(bill), 87)

    # Reference
    {pdf, y} =
      case bill.payment_reference do
        %PaymentReference{type: :non} ->
          {pdf, y}

        %PaymentReference{} = pr ->
          ref_text = PaymentReference.formatted_reference(pr) || ""
          draw_heading_value(pdf, text_x, y, Translation.get(:reference, lang), ref_text, 87)
      end

    # Additional information
    {pdf, y} =
      case bill.additional_information do
        nil ->
          {pdf, y}

        %AdditionalInformation{} = ai ->
          text = AdditionalInformation.formatted_string(ai)

          if text == "" do
            {pdf, y}
          else
            draw_heading_value(pdf, text_x, y, Translation.get(:additional_information, lang), text, 87)
          end
      end

    # Payable by
    {pdf, _y} =
      case bill.debtor do
        nil ->
          {pdf, y} = draw_heading_value(pdf, text_x, y, Translation.get(:payable_by_name, lang), "", 87)
          {draw_corner_marks(pdf, text_x, y - 1 * @mm, 65 * @mm, 25 * @mm), y - 27 * @mm}

        %Address{} = addr ->
          draw_heading_value(pdf, text_x, y, Translation.get(:payable_by, lang), Address.full_address(addr), 87)
      end

    pdf
  end

  defp draw_heading_value(pdf, x, y, heading, value_text, _max_chars) do
    pdf = pdf |> Pdf.set_font("Helvetica", @heading_font_size, bold: true)
    pdf = Pdf.text_at(pdf, {x, y}, heading)

    pdf = pdf |> Pdf.set_font("Helvetica", @value_font_size)
    lines = String.split(value_text, "\n")

    {pdf, new_y} =
      Enum.reduce(lines, {pdf, y - @line_height_pt}, fn line, {pdf_acc, ly} ->
        if line == "" do
          {pdf_acc, ly}
        else
          {Pdf.text_at(pdf_acc, {x, ly}, line), ly - @line_height_pt}
        end
      end)

    {pdf, new_y - 2 * @mm}
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
