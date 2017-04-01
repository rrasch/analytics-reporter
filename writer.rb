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
  end

  def add_row(row)
    @csv << row
    @xls.row(@xls.row_count).concat(row)
  end

  def files
    [@csv_file, @xls_file]
  end

  def close
    @cvs_close
    @xls.workbook.write(@xls_file)
  end

end

