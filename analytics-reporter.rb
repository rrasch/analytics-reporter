#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require "google/analytics/admin/v1alpha"
require "google/analytics/data/v1beta/analytics_data"
require 'fileutils'
require 'google/apis/analytics_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'json'
require 'pp'
require 'thor'
require_relative './config'
require_relative './util'
require_relative './writer'

IS_V3_DEPRECATED = true

BASEURL = "https://analytics.google.com/analytics/web/"

ENV['GOOGLE_APPLICATION_CREDENTIALS'] = File.join(
  Dir.home, '.analytics', 'analytics-ga4.json')

def sum_array(*arr)
  # pp arr
  return arr.transpose.map {|x| x.reduce(:+)}
end

def get_properties
  # Create a client object. The client can be reused for multiple calls.
  client = Google::Analytics::Admin::V1alpha::AnalyticsAdminService::Client.new

  # Create a request. To set request fields, pass in keyword arguments.
  request = Google::Analytics::Admin::V1alpha::ListAccountSummariesRequest.new

  # Call the list_account_summaries method.
  result = client.list_account_summaries request

  properties = {}

  # The returned object is of type Gapic::PagedEnumerable. You can iterate
  # over elements, and API calls will be issued to fetch pages as needed.
  result.each do |account|
    # Each element is of type ::Google::Analytics::Admin::V1alpha::AccountSummary.
    # p account
    account.property_summaries.each do |property_summary|
      # puts "#{account.display_name}: #{property_summary.display_name}"
      name = property_summary.display_name.sub(/\s+-\s+GA4$/, "")
      if name =~ /^Finding Aids/
        name = name.sub(/\s+Hosted at New York University$/, "")
      end
      properties[account.display_name + ":" + name] = property_summary.property
    end
  end

  return properties
end

def get_profiles(service)
  profiles = {}
  service.list_accounts.items.each do |account|
    service.list_profiles(account.id, '~all').items.each do |profile|
      name = profile.name.dup
      # puts "#{account.name} #{name}"
      if name.sub!(' (master view)', '')
        profiles[account.name + ":" + name] = profile
      end
    end
  end
  return profiles
end

# https://stackoverflow.com/questions/72254647/can-ga4-api-fetch-the-data-from-requests-made-with-a-combination-of-minute-and-r
def get_results(property, start_date, end_date)
  client = ::Google::Analytics::Data::V1beta::AnalyticsData::Client.new

  request = Google::Analytics::Data::V1beta::RunReportRequest.new(
    property: property,
    date_ranges: [
      { start_date: start_date, end_date: end_date }
    ],
    metrics: %w(sessions totalUsers screenPageViews).map { |m| { name: m } },
    keep_empty_rows: true,
  )

  ret = client.run_report(request)
  row = ret.rows[0]
  return row.metric_values.map(&:value).map(&:to_i)
end



##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  oob_uri = 'urn:ietf:wg:oauth:2.0:oob'
  client_secrets_path = File.join(Dir.home, '.analytics',
                                 'client_secret.json')
  credentials_path    = File.join(Dir.home, '.analytics',
                                 'analytics-reporter.yaml')
  scope = Google::Apis::AnalyticsV3::AUTH_ANALYTICS_READONLY

  FileUtils.mkdir_p(File.dirname(credentials_path))

  client_id = Google::Auth::ClientId.from_file(client_secrets_path)
  token_store = Google::Auth::Stores::FileTokenStore.new(
    file: credentials_path)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, scope, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(
      base_url: oob_uri)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: oob_uri)
  end
  credentials
end


def fmt_date(date)
  date.strftime('%Y-%m-%d')
end


def fmt_date_qry(date)
  date.strftime('%Y%m%d')
end


def calc_percent(r1, r2, col_num)
  val1 = r1[col_num].to_f
  val2 = r2[col_num].to_f
  # puts "val1=#{val1}"
  # puts "val2=#{val2}"
  if !val1.zero?
    ((val2 - val1) / val1).to_s + '%'
  else
    ''
  end
end


def get_analytics(service, profiles, properties, config)

  metrics = %w(ga:sessions ga:users ga:pageviews)
  metrics_str = metrics.join(',')

  all_csv_rows = []
  all_csv_rows.push(Array.new)

  prev_totals = Array.new(3, 0)
  totals = Array.new(3, 0)

  names = (profiles.keys() + properties.keys())

  puts "Sites that don't have both v3 and v4 properties:"
  names.select{|i| names.count(i) == 1}.sort.each do |n|
    if profiles.key?(n)
      puts "V3 #{n}"
    else
      puts "V4 #{n}"
    end
  end

  names = names.sort.uniq

  skip_list = config[:skip_list].to_h { |name| [name, 1] }

  names.each do |name|
    if skip_list.key?(name)
      puts "Skipping #{name} ..."
      next
    end

    account_name, site_name = name.split(":")

    ga_url = "https://analytics.google.com"

    prev_result_row = Array.new(3, 0)
    result_row = Array.new(3, 0)

    if profiles.key?(name)
      profile = profiles[name]
      # puts profile.inspect

      query =  "?_u.date00=#{fmt_date_qry(config[:start])}" +
               "&_u.date01=#{fmt_date_qry(config[:end])}"

      ga_url = BASEURL +
               "?authuser=1#report/defaultid/a#{profile.account_id}" +
               "w#{profile.internal_web_property_id}p#{profile.id}/" +
                CGI.escape(query) + "/"

      puts "Querying master view: #{name}"
      prev_result = service.get_ga_data("ga:#{profile.id}",
                                     fmt_date(config[:prev_start]),
                                     fmt_date(config[:prev_end]),
                                     metrics_str)

      result = service.get_ga_data("ga:#{profile.id}",
                                     fmt_date(config[:start]),
                                     fmt_date(config[:end]),
                                     metrics_str)

      # puts "prev_result: ", prev_result.inspect
      # puts "result: ", result.inspect

      prev_result_rows = prev_result.rows || [["0", "0", "0"]]
      result_rows = result.rows || [["0", "0", "0"]]

      prev_result_row = sum_array(prev_result_row, prev_result_rows[0].map(&:to_i))
      result_row = sum_array(result_row, result_rows[0].map(&:to_i))
    end

    if properties.key?(name)
      property = properties[name]
      prefix, prop_num = property.split("/")
      puts "Querying GA4 property: #{name} #{property}"

      query =  "_u.date00=#{fmt_date_qry(config[:start])}" +
               "&_u.date01=#{fmt_date_qry(config[:end])}"
             # '&_u..comparisons=[{"name":"sessions"}]'

      ga_url = BASEURL +
               "#/p#{prop_num}/reports/reportinghub?params=" +
               CGI.escape(query)

      prev_result_row =
        sum_array(
          prev_result_row,
          get_results(
            property,
            fmt_date(config[:prev_start]),
            fmt_date(config[:prev_end])
          )
        )

      result_row =
        sum_array(
          result_row,
          get_results(
            property,
            fmt_date(config[:start]),
            fmt_date(config[:end])
          )
        )
    end

    csv_row = []
    csv_row.push(account_name)
    csv_row.push([ga_url, site_name])
    (0..2).each do |n|
      csv_row.push(result_row[n])
      csv_row.push(calc_percent(prev_result_row, result_row, n))
      prev_totals[n] += prev_result_row[n].to_i
      totals[n] += result_row[n].to_i
    end

    all_csv_rows.push(csv_row)

  end

  all_csv_rows[0].push('All', 'All')
  (0..2).each do |n|
    all_csv_rows[0].push(totals[n])
    all_csv_rows[0].push(calc_percent(prev_totals, totals, n))
  end

  # pp all_csv_rows

  return all_csv_rows
end


config = ReportConfig.get_config

Util.check_output_exists(config, ['analytics'])

if IS_V3_DEPRECATED
  profiles = {}
else
  # Initialize the API
  ga_service = Google::Apis::AnalyticsV3::AnalyticsService.new
  ga_service.client_options.application_name = 'Analytics Reporter'
  ga_service.authorization = authorize

  profiles = get_profiles(ga_service)
end

properties = get_properties

file_prefix = 'analytics_report'

Dir.mktmpdir(file_prefix) do |tmpdir|

  writer = ReportWriter.new(config, tmpdir, file_prefix)

  writer.add_row(['DLTS collections quarterly report - analytics'])
  writer.add_row(['Year:', "FY#{config[:report_year]}"])
  writer.add_row(['Quarter:', config[:report_qtr]])
  writer.add_row(['Account', 'Property',
                  '# of sessions',  'Chg from prev qtr',
                  '# of users',     'Chg from prev qtr',
                  '# of pageviews', 'Chg from prev qtr'])

  all_csv_rows = get_analytics(ga_service, profiles, properties, config)

  all_csv_rows.sort_by { |x| x[2].to_i }.reverse.each do |val|
    writer.add_row(val)
  end

  Thor.new.print_table(all_csv_rows)

  writer.close

  Util.mail_and_copy(config, writer.files, 'Google Analytics')

end
