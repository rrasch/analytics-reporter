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

    if Dir.exist?(config[:output_dir])
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


  def self.parse_report(report_file)
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


  def self.gen_output_name(config, prefix, ext)
    name = File.join(config[:output_dir],
                     "#{prefix}_report_FY#{config[:report_year]}_" \
                     "#{config[:report_qtr]}.#{ext}")
  end


  def self.check_output_exists(config, prefix_list)
    existing = []
    prefix_list.each do |prefix|
      ['csv', 'xls'].each do |ext|
        outfile = gen_output_name(config, prefix, ext)
        if File.exist?(outfile)
          existing << outfile
        end
      end
    end

    unless existing.empty?
      warn "The following output files already exist."
      existing.each { |f| warn "  #{f}" }
      exit 1
    end
  end

end
