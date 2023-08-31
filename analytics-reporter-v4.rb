#!/usr/bin/env ruby

require "google/analytics/admin/v1alpha"
require "google/analytics/data/v1beta/analytics_data"
require 'pp'
require 'json'

ENV['GOOGLE_APPLICATION_CREDENTIALS'] = File.join(Dir.home, '.analytics', 'analytics-ga4.json')

LIMIT_SIZE = 1000

def list_account_summaries
  # Create a client object. The client can be reused for multiple calls.
  client = Google::Analytics::Admin::V1alpha::AnalyticsAdminService::Client.new

  # Create a request. To set request fields, pass in keyword arguments.
  request = Google::Analytics::Admin::V1alpha::ListAccountSummariesRequest.new

  # Call the list_account_summaries method.
  result = client.list_account_summaries request

  properties = []

  # The returned object is of type Gapic::PagedEnumerable. You can iterate
  # over elements, and API calls will be issued to fetch pages as needed.
  result.each do |item|
    # Each element is of type ::Google::Analytics::Admin::V1alpha::AccountSummary.
    #p item
    item.property_summaries.each do |property_summary|
      p property_summary
      properties << property_summary.property
    end
  end

  return properties
end

# https://stackoverflow.com/questions/72254647/can-ga4-api-fetch-the-data-from-requests-made-with-a-combination-of-minute-and-r
def get_results(property)
  client = ::Google::Analytics::Data::V1beta::AnalyticsData::Client.new

  offset = 0

  loop do
    request = Google::Analytics::Data::V1beta::RunReportRequest.new(
      property: property,
      date_ranges: [
        { start_date: '2023-04-01', end_date: '2023-09-30'}
      ],
      dimensions: %w(country).map { |d| { name: d } },
      metrics: %w(sessions totalUsers screenPageViews).map { |m| { name: m } },
      keep_empty_rows: false,
      offset: offset,
      limit: LIMIT_SIZE
    )

    ret = client.run_report(request)
    dimension_headers = ret.dimension_headers.map(&:name)
    metric_headers = ret.metric_headers.map(&:name)
    puts (dimension_headers + metric_headers).join(',')
    ret.rows.each do |row|
      puts (row.dimension_values.map(&:value) + row.metric_values.map(&:value)).join(',')
    end

    offset += LIMIT_SIZE

    break if ret.row_count <= offset
  end
end

properties = list_account_summaries
p properties

properties.each do |property|
  puts property
  get_results(property)
  exit
end

