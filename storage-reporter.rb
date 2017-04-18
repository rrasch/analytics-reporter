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
require 'spreadsheet'
require 'tempfile'
require 'yaml'
require_relative './config'
require_relative './util'
require_relative './writer'


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
    Util.commify(sprintf('%.2f', ((val2 - val1) / val1) * 100)) + '%'
  else
    return 'N/A'
  end
end


def get_partners(config)
  agent = Mechanize.new
  agent.add_auth(config[:rsbe_domain],
                 config[:rsbe_user], config[:rsbe_pass])

  partners = {}
  partners_url = "#{config[:rsbe_domain]}/api/v0/partners"
  partners_list = JSON.parse(agent.get(partners_url).content)
  partners_list.each do |partner|
    collections_url = "#{partner['url']}/colls"
    collections_list = JSON.parse(agent.get(collections_url).content)
    collections = collections_list.map { |h| [h['code'], h] }.to_h
    partner['collections'] = collections
    partners[partner['code']] = partner
  end
  #pp partners
  return partners
end


config = ReportConfig.get_config

install_dir = File.join(Dir.home, "storage-reports")

if config[:use_web]
  if Dir.exist?(install_dir)
    Dir.chdir(install_dir) do
      Util.do_cmd('git pull')
    end
  else
    Util.do_cmd("git clone '#{config[:report_repo]}' #{install_dir}")
  end
end

prev_report_file = get_report_file(config[:prev_end], install_dir)
report_file = get_report_file(config[:end], install_dir)
puts "previous report file: ", prev_report_file
puts "current report file: ", report_file

prev_totals = parse_report(prev_report_file)
totals = parse_report(report_file)

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
  writer.add_row_header(['Partner', 'Collection', 'Title',
                         'Files', 'Chg from prev qtr',
                         'Size in GB', 'Chg from prev qtr'])

  gigabyte = (10 ** 3) ** 3

  totals.sort_by { |k,v| v[:size] }.reverse.each do |key, val|
    unless key == :all || partners[val[:provider]].nil?
      collection = partners[val[:provider]]['collections'][val[:collection]]
      val[:title] = collection['name'] unless collection.nil?
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
    writer.add_row(data)
  end

  writer.close

  Util.mail_and_copy(config, writer.files, 'R* Storage')

end

