#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'sinatra'
require 'chartkick'
# require 'gruff'
require './util'

# g = Gruff::Line.new

# Chartkick.timeline [
#   ["Washington", "1789-04-29", "1797-03-03"],
#   ["Adams", "1797-03-03", "1801-03-03"],
#   ["Jefferson", "1801-03-03", "1809-03-03"]
# ]

foo = Hash.new

partner = 'cornell'
collection = 'aco'

key = "#{partner}/#{collection}".to_sym

gigabyte = (10 ** 3) ** 3

report_dir = "/home/rasan/storage-reports/data"

Dir.glob("#{report_dir}/*-storage-report.txt") do |file|
  time = Time.parse(File.basename(file).split('T').first)
  stats = Util.parse_report(file)
  foo[time] = stats[key][:size].to_f / gigabyte
end

puts foo.inspect

get '/' do
  @data = foo
  erb :linegraph
end

