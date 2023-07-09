#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simple_xlsx_reader'
require './lib/pdf'

pdf = Pdf.new
sheet = SimpleXlsxReader.open(ARGV[0]).sheets.first

def num(amount)
  return unless amount

  "#{amount}x"
end

def money(price)
  format('%.2f €', price).gsub('.', ',')
end

sheet.rows.slurp
nr, name = sheet.rows[2][6].split(" - ")
street, city = sheet.rows[4][6].split(", ")

title = "Auftragsbestätigung-#{nr}-#{name}"
pdf.add_header(title, <<~RECEIVER)
  #{name}
  #{street}
  #{city}
RECEIVER

out = false
order = {}
product = nil
total = 0
total_size = 0
buckets = []
table = []
sheet.rows.each do |row|
  if out
    product = row[1] unless row[1].nil?
    key = "#{product} - #{row[2]} - #{row[3]}"
    line_total = 0
    line_size = 0
    any = false

    row[4..-8][0...4 * buckets.size].each_slice(4) do |slice|
      # next if slice[0].nil?

      order[key] ||= []
      price = slice[0] ? money(slice[1]) : nil
      order[key] << [num(slice[0]), price]
      line_total += slice[0].to_i * slice[1].to_f
      line_size += slice[0].to_i
      any = true if slice[0]
      total += slice[0].to_i * slice[1].to_f
      total_size += slice[0].to_i
    end
    table << [product.to_s, row[3], *order[key].flatten, num(line_size), money(line_total)] if any
  elsif row[4] && row[5].nil? && row[8] && row[9].nil?
    buckets = []
    row[4..-8].each_slice(4) do |slice|
      buckets << { content: slice[0], colspan: 2, align: :center } unless slice[0].nil?
    end
  end
  out = true if row[1] == 'STYLE'
  next unless row[1].nil? && row[2].nil?

  if out && table.any?
    pdf.add_table(
      headings: ['Artikel', 'Farbe', *buckets, 'Anz', 'Preis'],
      rows: table
    )
    table = []
  end
  out = false
end

pdf.add_total_table(
  headings: [
    { content: '<b>Gesamt:</b>', align: :right, inline_format: true },
    num(total_size),
    money(total)
  ]
)

pdf.render("/output/#{title}.pdf")
