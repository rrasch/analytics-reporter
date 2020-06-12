#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'csv'
require 'spreadsheet'

class ReportWriter

  def initialize(config, tmpdir, prefix)
    basename = File.join(tmpdir,
      "#{prefix}_FY#{config[:report_year]}_#{config[:report_qtr]}")
    @csv_file = "#{basename}.csv"
    @csv = CSV.open(@csv_file, 'w')
    @xls_file = "#{basename}.xls"
    @xls = Spreadsheet::Workbook.new.create_worksheet
    @xls.name = prefix.split(/[ _]/).map {|w| w.capitalize}.join(' ')
    @xls.name << " FY#{config[:report_year]} #{config[:report_qtr]}"
    @fmt_title    = Spreadsheet::Format.new :align => :center
    @fmt_header   = Spreadsheet::Format.new :underline => :single
    @fmt_link     = Spreadsheet::Format.new :color => :blue,
                                            :underline => :single
    @fmt_qtr      = Spreadsheet::Format.new :weight => :bold
    @fmt_label    = Spreadsheet::Format.new :underline => :single
    @fmt_perc_dec = Spreadsheet::Format.new :color => :red,
                                            :number_format => '#,##0.00%'
    @fmt_perc_inc = Spreadsheet::Format.new :color => :green,
                                            :number_format => '#,##0.00%'
    @fmt_perc     = Spreadsheet::Format.new :color => :black,
                                            :number_format => '#,##0.00%'
    @fmt_dec      = Spreadsheet::Format.new :color => :black,
                                            :number_format => '#,##0.00'
    @fmt_int      = Spreadsheet::Format.new :color => :black,
                                            :number_format => '#,##0'

    #fmt_perc_str = '[Green]#,##0.00%;[Red]-#,##0.00%;0.00%'
    #@fmt_perc    = Spreadsheet::Format.new :number_format => fmt_perc_str

    [@fmt_perc_dec, @fmt_perc_inc, @fmt_perc,
        @fmt_dec, @fmt_int].each do |fmt|
      fmt.align = :right
      fmt.font.weight = :bold
    end
  end

  def add_row_header(row)
    add_row(row, @fmt_header)
  end

  def add_row(row, row_format = nil)
    row_num = @xls.row_count
    @xls.row(row_num).default_format = row_format unless row_format.nil?
    row.each_with_index do |val, i|
      fmt = nil
      if Array === val
        @xls[row_num, i] = Spreadsheet::Link.new(*val)
        row[i] = val[1]
        fmt = @fmt_link
      else
        cell_val = val
        val_str = val.to_s
        if val_str =~ /^(.*)%$/
          percent = $1.to_f
          if percent < 0
            fmt = @fmt_perc_dec
          elsif percent > 0
            fmt = @fmt_perc_inc
          else
            fmt = @fmt_perc
          end
          cell_val = percent
          row[i] = (percent * 100).round(3).to_s + '%'
        elsif val_str =~ /^\d+\.\d+$/
          fmt = @fmt_dec
          cell_val = val_str.to_f
        elsif val_str =~ /^\d+$/
          fmt = @fmt_int
          cell_val = val_str.to_i
        end
        @xls[row_num, i] = cell_val
      end
      @xls.row(row_num).set_format(i, fmt) if fmt
    end
    @csv << row
  end

  # http://stackoverflow.com/questions/11621919/using-ruby-spreadsheet-gem-is-there-a-way-to-get-cell-to-adjust-to-size-of-cont
  # Solution by CCinkosky
  # Auto adjust width of columns and height of rows based on
  # widest cell in a column and tallest cell in a row.
  # This method will loop through each column in the worksheet, then
  # loop through each cell in the column, finding the cell with the most
  # characters (+3 for a little extra space) and adjusting according to
  # that cell. It then does the same thing for the rows. This value
  # works great for font size 10, but to make sure it gets a little
  # bigger for larger fonts, it adjusts to the font size by calculating
  # the scale.
  def autofit(start_row = 0)
    (0...@xls.column_count).each do |col_idx|
      column_width = 0
      (start_row...@xls.row_count).each do |row_idx|
        cell_val = @xls[row_idx, col_idx].to_s
        scale = @xls.row(row_idx).format(col_idx).font.size / 10
        cell_width = ((cell_val.length + 3) * scale).round
        if cell_width > column_width
          column_width = cell_width
        end
      end
      @xls.column(col_idx).width = column_width
    end
    (0...@xls.row_count).each do |row_idx|
      row_height = 0
      (0...@xls.column_count).each do |col_idx|
        cell_val = @xls[row_idx, col_idx].to_s
        cell_height = @xls.row(row_idx).format(col_idx).font.size + 4
        if cell_height > row_height
          row_height = cell_height
        end
      end
      @xls.row(row_idx).height = row_height
    end
  end

  def files
    [@csv_file, @xls_file]
  end

  def close
    @csv.close
    autofit(1)
    @xls.merge_cells(0, 0, 0, @xls.column_count - 1)
    @xls.row(0).set_format(0, @fmt_title)
    @xls.row(1).set_format(1, @fmt_qtr)
    @xls.row(2).set_format(1, @fmt_qtr)
    @xls.row(3).default_format = @fmt_label
    @xls.workbook.write(@xls_file)
  end

end

