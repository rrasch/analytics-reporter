#!/usr/bin/env ruby

require 'csv'
require 'fileutils'

csv_files = ARGV

if csv_files.empty?
  abort("Usage: $0 CSV_FILE...")
end

fix_row = false
csv_files.each do |csv_file|
  fixed_file = "#{csv_file}.fixed"
  backup_file = "#{csv_file}.bak"
  CSV.open(fixed_file, "w+") do |fixed_csv|
    CSV.foreach(csv_file) do |row|
      fix_row = true if row[0] =~ /^all$/i
      if fix_row
        #orig_row = row.clone
        1.upto(row.size - 1) do |i|
          if row[i] =~ /^(.*)%$/
            row[i] = ($1.to_f * 100).round(3).to_s + '%'
            # puts row[i]
          end
        end
        #pp orig_row
        #pp row
      end
      fixed_csv << row
    end
  end
  FileUtils.mv(csv_file, backup_file)
  FileUtils.mv(fixed_file, csv_file)
  FileUtils.touch(csv_file, :mtime => File.mtime(backup_file))
end

