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
require 'pp'
require 'spreadsheet'
require 'tempfile'
require 'yaml'
require_relative './config'
require_relative './util'
require_relative './writer'


def parse_report(report_file)
  totals = Hash.new
  if report_file.nil?
    return totals
  end
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


def get_report_file(end_qtr, report_dir)
  report_date = Chronic.parse('last sunday',
                              :now => end_qtr.next_financial_quarter)
  date_expr = report_date.strftime('%Y%m%d')
  reports = Dir.glob("#{report_dir}/data/#{date_expr}*-preservation-*.txt")
  if reports.empty?
    raise "Can't find report file for #{date_expr}"
  end
  return reports.first
end


def calc_change(t1, t2, k1, k2)
  if t1.key?(k1) && t2.key?(k1) && t1[k1][k2] > 0
    val1 = t1[k1][k2].to_f
    val2 = t2[k1][k2].to_f
    #puts "val1=#{val1} val2=#{val2}"
    ((val2 - val1) / val1).to_s + '%'
  else
    return ''
  end
end


def get_partners(config)
  agent = Mechanize.new
  agent.add_auth(config[:rsbe_domain],
                 config[:rsbe_user], config[:rsbe_pass])

  api_url = "#{config[:rsbe_domain]}/api/v0"

  owners_url = "#{api_url}/owners"
  owners_list = JSON.parse(agent.get(owners_url).content)
  owners = owners_list.map { |h| [h['id'], h] }.to_h

  partners = {}
  partners_url = "#{api_url}/partners"
  partners_list = JSON.parse(agent.get(partners_url).content)
  partners_list.each do |partner|
    collections_url = "#{partner['url']}/colls"
    collections_list = JSON.parse(agent.get(collections_url).content)
    collections = {}
    collections_list.each do |coll|
      coll['owner_name'] = owners[coll['owner_id']]['name']
      collections[coll['code']] = coll
    end
    partner['collections'] = collections
    partners[partner['code']] = partner
  end
  #pp partners
  return partners
end


config = ReportConfig.get_config

Util.check_output_exists(config, ['storage', 'storage_trends'])

install_dir = File.join(Dir.home, "storage-reports")

if config[:use_web]
  if Dir.exist?(install_dir)
    Dir.chdir(install_dir) do
      Util.do_cmd('git pull')
    end
  else
    report_repo = config[:report_repo]
    if !report_repo.end_with?('.git')
      report_repo += '.git'
    end
    Util.do_cmd("git clone '#{report_repo}' #{install_dir}")
  end
end


first_report_file =
  Dir.glob("#{install_dir}/data/*-preservation-storage-report.txt").sort.first
first_report_date =
  Date.parse(File.basename(first_report_file).split('T').first)
puts first_report_date

prev_report_file = get_report_file(config[:prev_end], install_dir)
report_file = get_report_file(config[:end], install_dir)
puts "previous report file: ", prev_report_file
puts "current report file: ", report_file

prev_totals = parse_report(prev_report_file)
totals = parse_report(report_file)

reports_by_qtr = {}
end_qtr = config[:end]
num_labels = 0
while end_qtr > first_report_date
  num_labels += 1
  puts "end_qtr: #{end_qtr}"
  puts "end_qtr.financial_quarter: #{end_qtr.financial_quarter}"
  report_file = get_report_file(end_qtr, install_dir)
  puts report_file
  reports_by_qtr[end_qtr.financial_quarter] = parse_report(report_file)
  end_qtr = end_qtr.previous_financial_quarter.end_of_financial_quarter
end
# puts reports_by_qtr

if config[:use_web]
  partners = get_partners(config)
else
  partners = {}
end

file_prefix = 'storage_report'

Dir.mktmpdir(file_prefix) do |tmpdir|

  writer = ReportWriter.new(config, tmpdir, file_prefix)

  writer.add_row(['DLTS collections quarterly report - storage'])
  writer.add_row(['Year:', "FY#{config[:report_year]}"])
  writer.add_row(['Quarter:', config[:report_qtr]])
  writer.add_row_header(['Owner', 'Partner', 'Collection',
                         'Collection ID', 'Title', 'Classification',
                         'Item count', 'Chg from prev qtr',
                         'Size in GB', 'Chg from prev qtr'])

  trends_writer = ReportWriter.new(config, tmpdir, 'storage_trends_report')

  trends_writer.add_row(['DLTS collections quarterly report - storage trends'])

  blanks = [""] * 4
  year_labels = ['Year:', "FY#{config[:report_year]}"] + blanks
  qtr_labels  = ['Quarter:', config[:report_qtr]] + blanks
  end_qtr = config[:end]
  while end_qtr > first_report_date
    qtr, year = end_qtr.financial_quarter.split
    year = year.to_i + 1
    puts "year: #{year}"
    year_labels.push("FY#{year}")
    qtr_labels.push(qtr)
    end_qtr = end_qtr.previous_financial_quarter.end_of_financial_quarter
  end
  trends_writer.add_row(year_labels)
  trends_writer.add_row(qtr_labels)

  labels = [
    'Owner',
    'Partner',
    'Collection',
    'Collection ID',
    'Title',
    'Classification',
  ]
  labels.concat(Array.new(num_labels, 'Size in GB'))
  trends_writer.add_row_header(labels)

  gigabyte = (10 ** 3) ** 3

  totals.sort_by { |k,v| v[:size] }.reverse.each do |key, val|
    collection = nil
    unless key == :all || partners[val[:provider]].nil?
      collection = partners[val[:provider]]['collections'][val[:collection]]
    end
    collection ||= {}
    #pp collection

    #puts val
    data = []
    data.push(collection.fetch('owner_name', ''))
    data.push(val[:provider])
    data.push(val[:collection])
    data.push(collection.fetch('display_code', ''))
    data.push(collection.fetch('name', ''))
    data.push(collection.fetch('classification', ''))
    data.push(val[:num_files])
    data.push(calc_change(prev_totals, totals, key, :num_files))
    data.push(sprintf('%.2f', val[:size].to_f / gigabyte))
    data.push(calc_change(prev_totals, totals, key, :size))
    writer.add_row(data)

    data = []
    data.push(collection.fetch('owner_name', ''))
    data.push(val[:provider])
    data.push(val[:collection])
    data.push(collection.fetch('display_code', ''))
    data.push(collection.fetch('name', ''))
    data.push(collection.fetch('classification', ''))
    end_qtr = config[:end]
    while end_qtr > first_report_date
      #puts end_qtr.financial_quarter
      storage_totals = reports_by_qtr[end_qtr.financial_quarter]
      if storage_totals.has_key?(key)
        #puts storage_totals[key][:size]
        data.push(sprintf('%.2f', storage_totals[key][:size].to_f / gigabyte))
      else
        data.push("")
      end
      end_qtr = end_qtr.previous_financial_quarter.end_of_financial_quarter
    end
    trends_writer.add_row(data)

  end

  writer.close
  trends_writer.close

  Util.mail_and_copy(config, writer.files, 'R* Storage')
  Util.mail_and_copy(config, trends_writer.files, 'R* Storage Trends')

end
