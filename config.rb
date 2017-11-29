#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'fiscali'
require 'optparse'
require 'yaml'

class ReportConfig

  def self.get_config

    config = {
      :output_dir => Dir.home,
    }

    conf_dir = File.dirname(File.expand_path(__FILE__))

    yml = YAML.load_file(File.join(conf_dir, 'config.yaml'))

    config.merge!(yml)

    OptionParser.new do |opts|

      opts.banner = "Usage: #{$0} [options]"

      opts.on('-f', '--fiscal-qtr QTR', 'Fiscal Quarter, e.g. Q4/2016') do |f|
        config[:fiscal_qtr] = f
      end

      opts.on('-o', '--output-dir OUTPUT_DIR', 'Output directory') do |o|
        config[:output_dir] = o
      end

      opts.on('-h', '--help', 'Print help message') do
        puts opts
        exit
      end

    end.parse!

    Date.fiscal_zone = :us
    Date.fy_start_month = 9

    now = Date.today

    if !config[:fiscal_qtr].nil?
      if config[:fiscal_qtr] =~ /^Q([1234])\/(\d{4})$/
        qtr = $1.to_i
        year = $2.to_i
        start_of_year = Date.new(year - 1, 9, 1)
        config[:start] = start_of_year.beginning_of_financial_quarter(qtr)
      else
        puts "Quarter must be specified in the form Q[1234]/YYYY, e.g. Q4/2016"
        exit
      end
    else
      config[:start] = now.previous_financial_quarter
    end

    config[:end] = config[:start].end_of_financial_quarter
    config[:prev_start] = config[:start].previous_financial_quarter
    config[:prev_end] = config[:prev_start].end_of_financial_quarter

    puts config[:prev_start]
    puts config[:prev_end]
    puts config[:start]
    puts config[:end]

    if config[:end] >= now
      puts "Today's date must be after the financial quarter"
      exit
    end

    qtr, year = config[:start].financial_quarter.split
    config[:report_qtr] = qtr
    config[:report_year] = year.to_i + 1

    return config

  end

end

