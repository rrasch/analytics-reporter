#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'csv'
require 'spreadsheet'

class ReportWriter

  def initialize(config, tmpdir, prefix)
    basename = File.join(tmpdir,
      "#{prefix}_#{config[:report_qtr]}_#{config[:report_year]}")
    @csv_file = "#{basename}.csv"
    @csv = CSV.open(@csv_file, 'w')
    @xls_file = "#{basename}.xls"
    @xls = Spreadsheet::Workbook.new.create_worksheet
    @fmt_perc_dec = Spreadsheet::Format.new :color  => :red,
                                            :weight => :bold
    @fmt_perc_inc = Spreadsheet::Format.new :color  => :green,
                                            :weight => :bold
    @fmt_num      = Spreadsheet::Format.new :weight => :bold
  end

  def add_row(row)
    @csv << row
    row_num = @xls.row_count
    @xls.row(row_num).concat(row)
    row.each_with_index do |val, i|
      val_str = val.to_s
      fmt = nil
      if val_str =~ /^(.*)%$/
        percent = $1.to_f
        if percent < 0
          fmt = @fmt_perc_dec
        elsif percent > 0
          fmt = @fmt_perc_inc
        end
      elsif val_str =~ /^\d+$/
        fmt = @fmt_num
      end
      @xls.row(row_num).set_format(i, fmt) if fmt
    end
  end

  # http://stackoverflow.com/questions/11621919/using-ruby-spreadsheet-gem-is-there-a-way-to-get-cell-to-adjust-to-size-of-cont
  def autofit
    (0...@xls.column_count).each do |col|
      high = 1
      row = 0
      @xls.column(col).each do |cell|
        w = cell==nil || cell=='' ? 1 : cell.to_s.strip.split('').count+3
        ratio = @xls.row(row).format(col).font.size/10
        w = (w*ratio).round
        if w > high
          high = w
        end
        row=row+1
      end
      @xls.column(col).width = high
    end
    (0...@xls.row_count).each do |row|
      high = 1
      col = 0
      @xls.row(row).each do |cell|
        w = @xls.row(row).format(col).font.size+4
        if w > high
          high = w
        end
        col=col+1
      end
      @xls.row(row).height = high
    end
  end

  def files
    [@csv_file, @xls_file]
  end

  def close
    @cvs_close
    autofit
    @xls.workbook.write(@xls_file)
  end

end

