#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'chronic'
require 'csv'
require 'google/apis/analytics_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'fiscali'
require 'mail'
require 'optparse'
require 'pp'
require 'thor'
require 'yaml'

config = {
#   :start   => Chronic.parse('last week').strftime('%Y-%m-%d'),
#   :end     => Time.now.strftime('%Y-%m-%d'),
  :fiscal_qtr => Time.now.strftime('Q1/%y'),
  :outfile => 'out.csv',
}

yml = YAML.load_file('config.yaml')

config.merge!(yml)

OptionParser.new do |opts|

  opts.banner = "Usage: #{$0} [options]"

#   opts.on('-s', '--start START_DATE', 'Start date for query') do |s|
#     config[:start] = s
#   end
# 
#   opts.on('-e', '--end END_DATE', 'End date for query') do |e|
#     config[:end] = e
#   end

  opts.on('-f', '--fiscal-qtr', 'Fiscal Quarter, e.g. Q4/16') do |f|
    config[:fiscal_qtr] = f
  end

  opts.on('-o', '--outfile OUTFILE', 'Output CSV file') do |o|
    config[:outfile] = o
  end

  opts.on('-h', '--help', 'Print help message') do
    puts opts
    exit
  end

end.parse!

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

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Analytics Reporter'
CLIENT_SECRETS_PATH = File.join(Dir.home, '.analytics',
                               'client_secret.json')
CREDENTIALS_PATH    = File.join(Dir.home, '.analytics',
                               "analytics-reporter.yaml")
SCOPE = Google::Apis::AnalyticsV3::AUTH_ANALYTICS_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(
      base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

# Initialize the API
service = Google::Apis::AnalyticsV3::AnalyticsService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

csv = CSV.open(config[:outfile], 'w')

def fmt_date(date)
  date.strftime('%Y-%m-%d')
end

# class Numeric
#   def percent_of(n)
#     self.to_f / n.to_f * 100.0
#   end
# end

def calc_percent(r1, r2, col_num)
  val1 = r1[col_num].to_f
  val2 = r2[col_num].to_f
  #puts "val1=#{val1}"
  #puts "val2=#{val2}"
  if !val1.zero?
    sprintf('%.2f%', ((val2 - val1) / val1) * 100)
  else
    'N/A'
  end
end

csv << ['DLTS collections quarterly report']
csv << ['Year:', "FY#{now.financial_year}"]
csv << ['Quarter:', now.financial_quarter.split.first]
csv << ['Account',
        'Property',
        '# of sessions',  'Chg from prev qtr',
        '# of users',     'Chg from prev qtr',
        '# of pageviews', 'Chg from prev qtr'
       ]

metrics = %w(ga:sessions ga:users ga:pageviews)
metrics_str = metrics.join(',')

all_csv_rows = []
all_csv_rows.push(Array.new)

prev_totals = Array.new(3, 0)
totals = Array.new(3, 0)

service.list_accounts.items.each do |account|

  puts account.name

  service.list_profiles(account.id, '~all').items.each do |profile|
    view_name = profile.name.dup
    if view_name.sub!(' (master view)', '').nil?
      #puts "Ignoring #{view_name}"
      next
    end
    puts "Querying master view: #{view_name}"
    #puts profile.inspect
    prev_result = service.get_ga_data("ga:#{profile.id}",
                                   fmt_date(config[:prev_start]),
                                   fmt_date(config[:prev_end]),
                                   metrics_str)
  
    result = service.get_ga_data("ga:#{profile.id}",
                                   fmt_date(config[:start]),
                                   fmt_date(config[:end]),
                                   metrics_str)

    #puts "prev_result: ", prev_result.inspect
    #puts "result: ", result.inspect

    if !prev_result.rows.nil?
      prev_result_row = prev_result.rows[0]
    else
      prev_result_row = Array.new(3, '0')
    end

    if !result.rows.nil?
      result_row = result.rows[0]
    else
      result_row = Array.new(3, '0')
    end

    csv_row = []
    csv_row.push(account.name)
    csv_row.push(view_name)
    (0..2).each do |n|
      csv_row.push(result_row[n])
      csv_row.push(calc_percent(prev_result_row, result_row, n))
      prev_totals[n] += prev_result_row[n].to_i
      totals[n] += result_row[n].to_i
    end

    all_csv_rows.push(csv_row)

  end

end

all_csv_rows[0].push('All', 'All')
(0..2).each do |n|
  all_csv_rows[0].push(totals[n])
  all_csv_rows[0].push(calc_percent(prev_totals, totals, n))
end

# pp all_csv_rows

all_csv_rows.sort_by { |x| x[2].to_i }.reverse.each do |val|
  csv << val
end

csv.close

Thor.new.print_table(all_csv_rows)
  
desc = "Analytics Report for #{config[:start]} to #{config[:end]}"

mail = Mail.new do
  from     config[:mailfrom]
  to       config[:mailto]
  subject  desc
  body     desc
  add_file config[:outfile]
end

mail.delivery_method :sendmail

mail.deliver!
