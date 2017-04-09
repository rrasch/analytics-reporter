#!/usr/bin/env ruby
#
# Author: rasan@nyu.edu

require 'mail'
require 'open3'

class Util

  def self.mail_and_copy(config, files, report_name)

    desc = "#{report_name} Report for " +
           "#{config[:report_qtr]}/#{config[:report_year]} - " +
           "#{config[:start]} to #{config[:end]}"

    mail = Mail.new do
      from     config[:mailfrom]
      to       config[:mailto]
      subject  desc
      body     desc
    end

    files.each do |file|
      mail.add_file(file)
    end

    mail.delivery_method :sendmail

    mail.deliver!

    if Dir.exists?(config[:output_dir])
      FileUtils.cp(files, config[:output_dir])
    end

  end


  def self.do_cmd(cmd)
    output, status = Open3.capture2e(cmd)
    success = status.exitstatus.zero?
    raise "#{cmd} exited unsuccessfully: #{output}" if !success
  end


  def self.commify(number)
    number.to_s.reverse.gsub(/(\d+\.)?(\d{3})(?=\d)/, '\\1\\2,').reverse
  end

end

