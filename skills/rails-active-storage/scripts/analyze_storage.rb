#!/usr/bin/env ruby

# Active Storage script to analyze storage usage
# Usage: ruby scripts/analyze_storage.rb

require_relative "../config/environment"

class AnalyzeStorage
  def run
    puts "Active Storage Analysis"
    puts "=" * 50

    total_blobs = ActiveStorage::Blob.count
    total_size = ActiveStorage::Blob.sum(:byte_size) || 0
    
    puts "\nOverall Statistics:"
    puts "  - Total blobs: #{total_blobs}"
    puts "  - Total size: #{format_bytes(total_size)}"

    puts "\nBy Content Type:"
    content_type_stats.each do |type, count, size|
      puts "  - #{type}: #{count} files (#{format_bytes(size)})"
    end

    puts "\nUnattached Files:"
    unattached = ActiveStorage::Blob.unattached.count
    unattached_size = ActiveStorage::Blob.unattached.sum(:byte_size) || 0
    puts "  - Count: #{unattached}"
    puts "  - Size: #{format_bytes(unattached_size)}"

    puts "\nOldest Unattached:"
    oldest = ActiveStorage::Blob.unattached.order(created_at: :asc).first
    if oldest
      age = ((Time.current - oldest.created_at) / 86400).to_i
      puts "  - Age: #{age} days"
      puts "  - Filename: #{oldest.filename}"
      puts "  - Size: #{format_bytes(oldest.byte_size)}"
    else
      puts "  - None"
    end

    puts "\nLargest Files:"
    largest_files.each do |blob|
      puts "  - #{blob.filename}: #{format_bytes(blob.byte_size)}"
    end

    puts "\n" + "=" * 50
  end

  private

  def content_type_stats
    ActiveStorage::Blob.group(:content_type)
                       .select("content_type, COUNT(*) as count, SUM(byte_size) as total_size")
                       .order("total_size DESC")
                       .map { |b| [b.content_type, b.count, b.total_size] }
  end

  def largest_files
    ActiveStorage::Blob.order(byte_size: :desc).limit(10)
  end

  def format_bytes(bytes)
    return "0 B" if bytes.nil? || bytes.zero?

    case bytes
    when 0..1024
      "#{bytes} B"
    when 1024..1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    when 1024 * 1024..1024 * 1024 * 1024
      "#{(bytes / (1024 * 1024.0)).round(2)} MB"
    else
      "#{(bytes / (1024 * 1024 * 1024.0)).round(2)} GB"
    end
  end
end

analyzer = AnalyzeStorage.new
analyzer.run
