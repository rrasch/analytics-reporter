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
    @fmt_perc_dec = Spreadsheet::Format.new :color => :red,
                                            :weight => :bold
    @fmt_perc_inc = Spreadsheet::Format.new :color => :green,
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
      if val_str.starts_with?('-')
        fmt = @fmt_perc_dec
        puts fmt.inspect
      elsif val_str.ends_with?('%')
        fmt = @fmt_perc_inc
      elsif val_str =~ /^\d$/
        fmt = @fmt_num
      end
      @xls.row(row_num).set_format(i, fmt) if fmt
    end
  end

  def files
    [@csv_file, @xls_file]
  end

  def close
    @cvs_close
    @xls.workbook.write(@xls_file)
  end

end

