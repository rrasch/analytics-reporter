#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'chronic'
require 'csv'
require 'google/apis/analytics_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'mail'
require 'optparse'
require 'thor'

config = {
  :start   => Chronic.parse('last week').strftime('%Y-%m-%d'),
  :end     => Time.now.strftime('%Y-%m-%d'),
  :outfile => 'out.csv',
}

# puts config[:start]
# puts config[:end]

OptionParser.new do |opts|

  opts.banner = "Usage: #{$0} [options]"

  opts.on('-s', '--start START_DATE', 'Start Date') do |s|
    config[:start] = s
  end

  opts.on('-e', '--end END_DATE', 'End Date') do |e|
    config[:end] = e
  end

  opts.on('-o', '--outfile OUTFILE', 'Output CSV File') do |o|
    config[:outfile] = o
  end

  opts.on('-h', '--help', 'Print help message') do
    puts opts
    exit
  end

end.parse!



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

service.list_profiles('~all', '~all').items.each do |profile|
  puts profile.name
  dimensions = %w(ga:date)
  metrics = %w(ga:sessions ga:users ga:newUsers ga:percentNewSessions
               ga:sessionDuration ga:avgSessionDuration)
  sort = %w(ga:date)
  result = service.get_ga_data("ga:#{profile.id}",
                                 config[:start],
                                 config[:end],
                                 metrics.join(','))
                                 #dimensions: dimensions.join(','),
                                 #sort: sort.join(','))

  data = []
  data.push(result.column_headers.map { |h| h.name })
  data.push(*result.rows)
  puts "FOO", result.inspect
  if result.total_results > 0
    csv << result.rows[0]
    Thor.new.print_table(data)
  end
end

