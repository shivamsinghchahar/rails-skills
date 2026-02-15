#!/usr/bin/env ruby

# Active Storage script to purge unattached blobs
# Usage: ruby scripts/purge_unattached.rb [days_old=2]

require_relative "../config/environment"

class PurgeUnattached
  def initialize(days_old = 2)
    @days_old = days_old
    @cutoff_date = days_old.days.ago
  end

  def run
    puts "Purging unattached blobs older than #{@days_old} days..."
    puts "Cutoff date: #{@cutoff_date}"
    puts

    unattached_blobs = ActiveStorage::Blob.unattached
                                          .where("created_at <= ?", @cutoff_date)
    
    total = unattached_blobs.count
    
    if total.zero?
      puts "✓ No unattached blobs found"
      return
    end

    puts "Found #{total} unattached blobs to purge"
    puts

    purged = 0
    errors = 0

    unattached_blobs.find_each.with_index do |blob, index|
      begin
        size = blob.byte_size
        filename = blob.filename
        
        blob.purge_later
        
        puts "[#{index + 1}/#{total}] Purging: #{filename} (#{format_bytes(size)})"
        purged += 1
      rescue => e
        puts "[#{index + 1}/#{total}] Error purging: #{e.message}"
        errors += 1
      end
    end

    puts
    puts "=" * 50
    puts "✓ Complete!"
    puts "  - Purged: #{purged} blobs"
    puts "  - Errors: #{errors}"
    puts "=" * 50
  end

  private

  def format_bytes(bytes)
    return "0 B" if bytes.nil? || bytes.zero?

    case bytes
    when 0..1024
      "#{bytes} B"
    when 1024..1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    else
      "#{(bytes / (1024 * 1024.0)).round(2)} MB"
    end
  end
end

days = ARGV[0]&.to_i || 2
purger = PurgeUnattached.new(days)
purger.run
