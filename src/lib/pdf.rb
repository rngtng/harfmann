# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

Prawn::Fonts::AFM.hide_m17n_warning = true

class Pdf
  include Prawn::View

  BASE_SIZE = 10
  MAX_LINES = 30
  HEADER = <<~HEADER
    Sarah Harfmann, Eisenbahnstraße 6, 10997 Berlin
    0176 - 96 74 36 29, post@harfmann-design.com, www.harfmann-design.com
    DE 260730276 Steuernummer 35/331/01489
  HEADER

  def initialize
    @lines = 0
    font_families.update(
      'SuperGrotesk' => {
        normal: './assets/fonts/SuperGrotesk.ttf',
        bold: './assets/fonts/SuperGrotesk-Bold.ttf'
      }
    )
  end

  def add_header(title, receiver)
    move_up 10
    image './assets/logo.jpeg', width: 100
    move_up 10
    font 'SuperGrotesk'
    text(HEADER,
         size: BASE_SIZE - 2,
         leading: 2)
    move_down BASE_SIZE

    text(
      receiver,
      size: BASE_SIZE,
      leading: 2
    )
    move_down 2 * BASE_SIZE

    text(
      Time.now.strftime('%d.%m.%Y'),
      size: BASE_SIZE
    )
    move_down BASE_SIZE

    text(
      title,
      size: BASE_SIZE + 2,
      style: :bold
    )
    move_down 3 * BASE_SIZE

    text(
      'Folgende Artikel werden geliefert:',
      size: BASE_SIZE
    )
    move_down 10
    @lines += 10
  end

  def add_pagenumbers
    number_pages('Seite <page>/<total>', {
                   at: [bounds.right - 150, 0],
                   size: BASE_SIZE - 2,
                   # width: 150,
                   align: :right
                 })
  end

  def add_table(headings:, rows:)
    next_page if @lines + rows.size > MAX_LINES
    font 'Helvetica'
    table([headings, *rows], width: 540, cell_style: { size: BASE_SIZE - 4, overflow: :shrink_to_fit }, column_widths: {
            0 => 100,
            1 => 45,
            -2 => 20,
            -1 => 45
          }) do
      cells.border_width = 0.5
      row(0).columns(0..-1).borders = [:bottom]
      row(0).columns(0..-1).border_width = 1
      row(0..-1).columns(0..-2).align = :center
      row(0..-1).columns(-1).align = :right
    end
    move_down 20
    @lines += rows.size + 2
  end

  def add_total_table(rows:, total_table_width: 540)
    next_page if @lines + 1 > MAX_LINES
    font 'Helvetica'
    table(rows, width: total_table_width, cell_style: { size: BASE_SIZE - 4, overflow: :shrink_to_fit },
                column_widths: {
                  1 => 25,
                  2 => 45
                }) do
      cells.border_width = 0.5
      row(0).columns(0..2).borders = [:top]
      row(1..10).columns(0..2).borders = []
      row(0..10).columns(0..2).border_width = 1
      row(0..10).columns(0..2).align = :right
    end
    move_down 20
    @lines += 2
  end

  def add_info
    font 'SuperGrotesk'
    move_down 10
    text("Wir bitten um die Überweisung der Abschlagszahlung innerhalb der kommenden 7 Werktagen\n\n",
         size: BASE_SIZE)
    move_down 10
  end

  def add_footer
    font 'SuperGrotesk'
    move_down 20
    text("Vielen Dank für ihren Einkauf bei harfmann piccolino\n\n",
         size: BASE_SIZE)
    move_down 10

    text("Herzliche Grüße,\n harfmann piccolino",
         size: BASE_SIZE)

    move_down 20

    text('GLS Bank   <b>IBAN</b> DE2643 0609 6710 6376 5400   <b>BIC</b> GENODEM 1 GLS',
         size: BASE_SIZE - 2,
         inline_format: true,
         align: :center)
  end

  def render(filename)
    add_footer
    add_pagenumbers
    render_file(filename)
  end

  private

  def next_page
    move_down 20
    start_new_page
    @lines = 0
  end
end
