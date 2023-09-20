#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simple_xlsx_reader'
require './lib/pdf'

DEFAULT_TAX = 19

def num(amount)
  return unless amount

  "#{amount}x"
end

def money(price)
  format('%.2f €', price).gsub('.', ',')
end

def clean_table(buckets, table)
  # return [buckets, table]
  found = []
  new_table = []
  # require "pry";binding.pry
  table.transpose.each_with_index do |row, i|
    if row.compact.empty?
      found << ((i - 2) / 2)
    else
      new_table << row
    end
  end
  [buckets.reject.with_index { |_, i| found.include?(i) }, new_table.transpose]
end

sheet = 0
add_info = false
add_shipping = false
add_total = true
tax = (ARGV[2] || DEFAULT_TAX).to_i

title = case ARGV[1]
        when 'ORDER'
          "Auftragsbestätigung"
        when 'PREINVOICE'
          add_info = true
          "Abschlagsrechnung"
        when 'DELIVERY'
          add_total = false
          "Lieferschein"
        when 'DELIVERY1'
          add_total = false
          sheet = 1
          "Lieferschein I "
        when 'PREINVOICE2'
          add_info = true
          add_shipping = true
          "Abschlagsrechnung II"
        else
          add_shipping = true
          "Rechnung"
        end

pdf = Pdf.new
sheet = SimpleXlsxReader.open(ARGV[0]).sheets[sheet]
sheet.rows.slurp
nr, name = sheet.rows[2][6].split(' - ')
title += " #{nr}"
street, city = sheet.rows[4][6].split(', ')

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
shipping = []
sheet.rows.each do |row|
  if out
    product = row[1] unless row[1].nil?
    key = "#{product} - #{row[2]} - #{row[3]}"
    line_total = 0
    line_size = 0
    any = false

    row[4..-8][0...(4 * buckets.size)].each_slice(4) do |slice|
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

  if row[1] == 'Versandkosten'
    row[4..-8].each_slice(4) do |slice|
      shipping << [slice[0], slice[1]] if slice[0]
    end
  end

  next unless row[1].nil? && row[2].nil?

  if out && table.any?
    table_buckets, clean_table = clean_table(buckets, table)
    pdf.add_table(
      headings: ['Artikel', 'Farbe', *table_buckets, 'Anz', 'Preis'],
      rows: clean_table
    )
    table = []
  end
  out = false
end

brutto = total * (1 + (tax / 100.0))

rows = [[
  { content: '<b>Gesamtbetrag netto:</b>', inline_format: true },
  num(total_size),
  money(total)
]]

if tax == DEFAULT_TAX && ARGV[1] != 'ORDER'
  rows << [
    'zzgl. USt.:',
    "#{tax}%",
    money(brutto - total)
  ]
  rows << [
    { content: '<b>Gesamtbetrag brutto:</b>', inline_format: true },
    '',
    { content: "<b>#{money(brutto)}</b>", inline_format: true }
  ]
end

if ARGV[1] == 'PREINVOICE'
  rows << [
    { content: '<b>Abschlagszahlung I:</b>', inline_format: true },
    '50%',
    { content: "<b>#{money(brutto * 0.5)}</b>", inline_format: true }
  ]

elsif ARGV[1] == 'PREINVOICE2'
  rows << [
    { content: '<b>Abschlagszahlung I:</b>', inline_format: true },
    '50%',
    { content: "- #{money(brutto * 0.5)}", inline_format: true }
  ]
  brutto *= 0.5
end

total_table_width = 540
if add_shipping
  rows << [
    { content: '<b>Versandkosten:</b>', inline_format: true },
    '',
    ''
  ]

  shipping.each do |num, costs|
    rows << [
      { content: "#{num}x #{money(costs)}", inline_format: true, colspan: 2 },
      { content: "+ #{money(num * costs)}", inline_format: true }
    ]
    brutto += num * costs
  end
  total_table_width = 960

  row_title = ARGV[1] == 'PREINVOICE2' ? 'Gesamtbetrag Abschlagszahlung II' : 'Rechnungsbetrag'
  rows << [
    { content: "<b>#{row_title}:</b>", inline_format: true },
    '',
    { content: "<b>#{money(brutto)}</b>", inline_format: true }
  ]
end

pdf.add_total_table(rows:, total_table_width:) if add_total

pdf.add_info("\n\nWir bitten um Überweisung der Abschlagszahlung innerhalb der kommenden 7 Werktage.\n\n") if add_info
if tax != DEFAULT_TAX
  pdf.add_info('Hier wird das „Reverse-Charge-Verfahren“ Übergang der Steuerschuldnersachaft auf den Leistungsempfänger angewendet.')
end

filename = "#{title}-#{name}.pdf".gsub(' ', '-')
pdf.render("/output/#{filename}")
