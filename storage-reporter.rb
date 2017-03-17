#!/usr/bin/env ruby

require 'chronic'
require 'csv'
require 'fiscali'
require 'json'
require 'mail'
require 'mechanize'
require 'tempfile'
require 'yaml'

tmp = Tempfile.new(['storage-reports', '.csv'])

config = YAML.load_file('config.yaml')

repo = config[:storage_repo]

install_dir = "#{Dir.home}/storage-reports"

if config[:use_storage_repo]
  if Dir.exist?(install_dir)
    Dir.chdir(install_dir) do
      system('git pull')
    end
  else
    system("git clone '#{repo}' #{install_dir}")
  end
end

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

now = Date.today
Date.fiscal_zone = :us
Date.fy_start_month = 9

config[:start] =  now.previous_financial_quarter
config[:end] = config[:start].end_of_financial_quarter

config[:prev_start] = config[:start].previous_financial_quarter
config[:prev_end] = config[:prev_start].end_of_financial_quarter

puts config[:prev_start]
puts config[:prev_end]
puts config[:start]
puts config[:end]

def get_report_file(end_qtr, report_dir)
  report_date = Chronic.parse('last sunday', :now => end_qtr.next_financial_quarter)
  date_expr = report_date.strftime('%Y%m%d')
  Dir.glob("#{report_dir}/data/#{date_expr}*.txt").first
end

prev_report_file = get_report_file(config[:prev_end], install_dir)
report_file = get_report_file(config[:end], install_dir)
puts prev_report_file
puts report_file

prev_totals = parse_report(prev_report_file)
totals = parse_report(report_file)

csv = CSV.open(tmp.path, 'w')

csv << ['DLTS collections quarterly report - storage']
csv << ['Year:', "FY#{now.financial_year}"]
csv << ['Quarter:', now.financial_quarter.split.first]
csv << ['Partner', 'Collection', 'Title',
        'Files', 'Chg from prev qtr',
        'Size in GB', 'Chg from prev qtr',
       ]

rstar_base = config[:rstar_dir]

agent = Mechanize.new
agent.add_auth(config[:rsbe_domain], config[:rsbe_user], config[:rsbe_pass])

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
  data.push(sprintf('%.2f GB', val[:size].to_f / gigabyte))
  data.push(calc_change(prev_totals, totals, key, :size))
  csv << data
end

csv.close

desc = "Storage Report for #{now.financial_quarter}"

outfile = "storage_report_#{now.financial_quarter}.csv"
outfile.gsub!(' ', '_')

mail = Mail.new do
  from     config[:mailfrom]
  to       config[:mailto]
  subject  desc
  body     desc
  add_file :filename => outfile, :content => tmp.read
end

mail.delivery_method :sendmail

mail.deliver!

tmp.close

