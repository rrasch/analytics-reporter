#!/usr/bin/env ruby

require 'csv'
require 'fiscali'
require 'json'
require 'mechanize'
require 'yaml'

report_file = "in.txt"

config = YAML.load_file('config.yaml')

def parse_report(report_file)
  totals = Hash.new
  File.open(report_file).each do |line|
    if line =~ /DATESTAMP/
      next
    end
    puts line
    path, oxum = line.split(':Arbitrary-Oxum: ')
    puts path
    puts oxum
    provider, collection = path.split('/').slice(1,2)
    puts provider
    puts collection
    size, num_files = oxum.split('.')
    puts size
    puts num_files
    key = "#{provider}/#{collection}".to_sym
    puts "key #{key}"
    if !totals.key?(key)
      totals[key] = {:size => 0,
                     :num_files => 0,
                     :provider => provider,
                     :collection => collection}
    end
    totals[key][:size] += size.to_i
    totals[key][:num_files] += num_files.to_i
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

now = Date.today
Date.fiscal_zone = :us
Date.fy_start_month = 9

totals = parse_report(report_file)

csv = CSV.open('stor.csv', 'w')

csv << ['DLTS collections quarterly report - storage']
csv << ['Year:', "FY#{now.financial_year}"]
csv << ['Quarter:', now.financial_quarter.split.first]
csv << ['Partner', 'Collection', 'Title',
        'Files', 'Chg from prev qtr',
        'Size in GB', 'Chg from prev qtr',
       ]

rstar_base = "/content/prod/rstar/content"

agent = Mechanize.new
agent.add_auth(config[:rsbe_domain], config[:rsbe_user], config[:rsbe_pass])

totals.each do |key, val|
  partner_file = "#{rstar_base}/#{val[:provider]}/partner_url"
  collection_file = "#{rstar_base}/#{val[:provider]}/#{val[:collection]}/collection_url"
  if File.exist?(partner_file)
    val[:partner_name] = get_rstar_name(partner_file, agent)
  end
  if File.exist?(collection_file)
    val[:collection_name] = get_rstar_name(collection_file, agent)
  end
  puts val
end

totals.each do |key, val|
  puts val
  data = []
  data.push(val[:provider])
  data.push(val[:collection])
  data.push(val[:num_files])
  data.push(val[:size])
  csv << data
end

