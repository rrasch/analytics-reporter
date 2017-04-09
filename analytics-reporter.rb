#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'google/apis/analytics_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'thor'
require_relative './config'
require_relative './util'
require_relative './writer'


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


def calc_percent(r1, r2, col_num)
  val1 = r1[col_num].to_f
  val2 = r2[col_num].to_f
  #puts "val1=#{val1}"
  #puts "val2=#{val2}"
  if !val1.zero?
    Util.commify(sprintf('%.2f', ((val2 - val1) / val1) * 100)) + '%'
  else
    'N/A'
  end
end


def get_analytics(service, config)

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
        csv_row.push(Util.commify(result_row[n]))
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

  return all_csv_rows
end


config = ReportConfig.get_config

# Initialize the API
ga_service = Google::Apis::AnalyticsV3::AnalyticsService.new
ga_service.client_options.application_name = 'Analytics Reporter'
ga_service.authorization = authorize

file_prefix = 'google_analytics_report'

Dir.mktmpdir(file_prefix) do |tmpdir|

  writer = ReportWriter.new(config, tmpdir, file_prefix)

  writer.add_row(['DLTS collections quarterly report'])
  writer.add_row(['Year:', "FY#{config[:report_year]}"])
  writer.add_row(['Quarter:', config[:report_qtr]])
  writer.add_row(['Account', 'Property',
                  '# of sessions',  'Chg from prev qtr',
                  '# of users',     'Chg from prev qtr',
                  '# of pageviews', 'Chg from prev qtr'])

  all_csv_rows = get_analytics(ga_service, config)

  all_csv_rows.sort_by { |x| x[2].to_i }.reverse.each do |val|
    writer.add_row(val)
  end

  Thor.new.print_table(all_csv_rows)

  writer.close

  Util.mail_and_copy(config, writer.files, 'Google Analytics')

end

