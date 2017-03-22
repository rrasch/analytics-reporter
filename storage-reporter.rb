#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'chronic'
require 'csv'
require 'fiscali'
require 'json'
require 'mail'
require 'mechanize'
require 'optparse'
require 'tempfile'
require 'yaml'
require './config'


def parse_report(report_file)
  totals = Hash.new
  totals[:all] = {
                   :size       => 0,
                   :num_files  => 0,
                   :provider   => 'all',
                   :collection => 'all'
                 }
  File.open(report_file).each do |line|
    next if line =~ /DATESTAMP/
    #puts line
    path, oxum = line.split(':Arbitrary-Oxum: ')
    #puts path
    #puts oxum
    provider, collection = path.split('/').slice(1,2)
    #puts provider
    #puts collection
    size, num_files = oxum.split('.')
    #puts size
    #puts num_files
    key = "#{provider}/#{collection}".to_sym
    #puts "key #{key}"
    if !totals.key?(key)
      totals[key] = {
                      :size       => 0,
                      :num_files  => 0,
                      :provider   => provider,
                      :collection => collection
                    }
    end
    totals[key][:size] += size.to_i
    totals[key][:num_files] += num_files.to_i
    totals[:all][:size] += size.to_i
    totals[:all][:num_files] += num_files.to_i
  end
  return totals
end


def get_rstar_name(file, agent)
  url = File.open(file).first
  puts url
  page = agent.get(url)
  rstar_param = JSON.parse(page.content)
  puts rstar_param
  return rstar_param['name']
end


def calc_percent(a, b)
  ((b.to_f - a.to_f) / a.to_f) * 100
end


def get_report_file(end_qtr, report_dir)
  report_date = Chronic.parse('last sunday',
                              :now => end_qtr.next_financial_quarter)
  date_expr = report_date.strftime('%Y%m%d')
  Dir.glob("#{report_dir}/data/#{date_expr}*.txt").first
end


def calc_change(t1, t2, k1, k2)
  if t1.key?(k1) && t2.key?(k1) && t1[k1][k2] > 0
    val1 = t1[k1][k2].to_f
    val2 = t2[k1][k2].to_f
    #puts "val1=#{val1} val2=#{val2}"
    sprintf('%.2f%', ((val2 - val1) / val1) * 100)
  else
    return 'N/A'
  end
end


config = ReportConfig.get_config

install_dir = File.join(Dir.home, "storage-reports")

if config[:use_storage_repo]
  if Dir.exist?(install_dir)
    Dir.chdir(install_dir) do
      system('git pull')
    end
  else
    system("git clone '#{config[:storage_repo]}' #{install_dir}")
  end
end

prev_report_file = get_report_file(config[:prev_end], install_dir)
report_file = get_report_file(config[:end], install_dir)
puts prev_report_file
puts report_file

prev_totals = parse_report(prev_report_file)
totals = parse_report(report_file)

tmp = Tempfile.new(['storage-report', '.csv'])

csv = CSV.open(tmp.path, 'w')

csv << ['DLTS collections quarterly report - storage']
csv << ['Year:', "FY#{config[:start].financial_year + 1}"]
csv << ['Quarter:', config[:start].financial_quarter.split.first]
csv << ['Partner', 'Collection', 'Title',
        'Files', 'Chg from prev qtr',
        'Size in GB', 'Chg from prev qtr',
       ]

rstar_base = config[:rstar_dir]

agent = Mechanize.new
agent.add_auth(config[:rsbe_domain], config[:rsbe_user], config[:rsbe_pass])

gigabyte = (10 ** 3) ** 3

totals.sort_by { |k,v| v[:size] }.reverse.each do |key, val|

  unless key == :all
    partner_url_file    =  "#{rstar_base}/#{val[:provider]}/partner_url"
    collection_url_file =  "#{rstar_base}/#{val[:provider]}/"
    collection_url_file << "#{val[:collection]}/collection_url"
    title = ""
    if File.exist?(partner_url_file)
      val[:partner_name] = get_rstar_name(partner_url_file, agent)
      title << val[:partner_name]
    end
    if File.exist?(collection_url_file)
      val[:collection_name] = get_rstar_name(collection_url_file, agent)
      title << ' - ' unless title.empty?
      title << val[:collection_name]
    end
    val[:title] = title
  end

  #puts val
  data = []
  data.push(val[:provider])
  data.push(val[:collection])
  data.push(val[:title])
  data.push(val[:num_files])
  data.push(calc_change(prev_totals, totals, key, :num_files))
  data.push(sprintf('%.2f', val[:size].to_f / gigabyte))
  data.push(calc_change(prev_totals, totals, key, :size))
  csv << data
end

csv.close

qtr, year = config[:start].financial_quarter.split
year = year.to_i + 1

desc = "R* Storage Report for " +
       "#{qtr}/#{year} - #{config[:start]} to #{config[:end]}"

outfile = "storage_report_#{qtr}_#{year}.csv"

mail = Mail.new do
  from     config[:mailfrom]
  to       config[:mailto]
  subject  desc
  body     desc
  add_file :filename => outfile, :content => tmp.read
end

mail.delivery_method :sendmail

mail.deliver!

FileUtils.cp(tmp.path, File.join(config[:output_dir], outfile))

tmp.close!

