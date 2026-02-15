#!/usr/bin/env ruby

# Active Storage script to upload a file and create a model attachment
# Usage: ruby scripts/upload_document.rb app/models/user.rb 1

require_relative "../config/environment"

class UploadDocument
  def initialize(file_path, model_name, record_id)
    @file_path = file_path
    @model_name = model_name.classify
    @record_id = record_id
  end

  def run
    unless File.exist?(@file_path)
      puts "Error: File not found at #{@file_path}"
      return false
    end

    model_class = @model_name.constantize
    record = model_class.find(@record_id)

    unless record.respond_to?(:file)
      puts "Error: #{@model_name} doesn't have a file attachment"
      return false
    end

    file_name = File.basename(@file_path)
    content_type = mime_type(@file_path)

    record.file.attach(
      io: File.open(@file_path),
      filename: file_name,
      content_type: content_type
    )

    puts "✓ Successfully uploaded #{file_name} to #{@model_name}##{@record_id}"
    puts "  - Size: #{format_bytes(record.file.byte_size)}"
    puts "  - Type: #{content_type}"
  end

  private

  def mime_type(path)
    case File.extname(path).downcase
    when ".pdf"
      "application/pdf"
    when ".jpg", ".jpeg"
      "image/jpeg"
    when ".png"
      "image/png"
    when ".gif"
      "image/gif"
    when ".docx"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    when ".doc"
      "application/msword"
    else
      "application/octet-stream"
    end
  end

  def format_bytes(bytes)
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    else
      "#{(bytes / (1024 * 1024.0)).round(2)} MB"
    end
  end
end

if ARGV.length < 3
  puts "Usage: ruby scripts/upload_document.rb <file_path> <model_name> <record_id>"
  puts "Example: ruby scripts/upload_document.rb /path/to/file.pdf User 1"
  exit 1
end

uploader = UploadDocument.new(ARGV[0], ARGV[1], ARGV[2])
uploader.run
