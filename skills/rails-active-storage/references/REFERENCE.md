# Active Storage Advanced Reference

Comprehensive reference for advanced Active Storage topics, production patterns, and integration scenarios.

## Advanced Deployment Patterns

### Multi-Region S3 Setup

For global scale with low-latency access:

```yaml
# config/storage.yml
s3_us_east:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: my-app-us-east-<%= Rails.env %>

s3_eu_west:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: eu-west-1
  bucket: my-app-eu-west-<%= Rails.env %>

s3_ap_southeast:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: ap-southeast-1
  bucket: my-app-ap-southeast-<%= Rails.env %>
```

Route by user location in controller:

```ruby
class ApplicationController < ActionController::Base
  def storage_service
    case current_user&.region
    when "eu"
      :s3_eu_west
    when "ap"
      :s3_ap_southeast
    else
      :s3_us_east
    end
  end
end
```

### Mirror Service for Migration

Temporarily mirror to new service while migrating:

```yaml
production:
  service: Mirror
  primary: s3_old
  mirrors:
    - s3_new
```

Migrate existing files:

```ruby
# lib/tasks/migrate_storage.rake
namespace :active_storage do
  desc "Migrate files from old to new service"
  task migrate_to_new_service: :environment do
    ActiveStorage::Blob.find_each do |blob|
      puts "Migrating #{blob.filename}..."
      
      # Download from old service
      old_service = ActiveStorage::Blob.service_for_key(blob.key)
      content = old_service.download(blob.key)
      
      # Upload to new service
      new_service = ActiveStorage::Service.configure(:s3_new, {})
      new_service.upload(blob.key, StringIO.new(content))
    end
  end
end
```

## Custom Storage Service

Implement a custom storage backend:

```ruby
# app/services/custom_storage_service.rb
class CustomStorageService < ActiveStorage::Service
  def initialize(**options)
    @options = options
    @bucket = options[:bucket]
    @region = options[:region]
  end

  def upload(key, io, checksum: nil)
    # Your upload implementation
    File.write(local_path(key), io.read)
  end

  def download(key)
    File.read(local_path(key))
  end

  def delete(key)
    File.delete(local_path(key)) if File.exist?(local_path(key))
  end

  def exist?(key)
    File.exist?(local_path(key))
  end

  def url(key, expires_in:, disposition:, filename:, content_type:)
    # Generate URL for accessing file
    "#{@options[:url_base]}/#{key}"
  end

  private
    def local_path(key)
      File.join(@options[:root], key)
    end
end
```

Register in config:

```ruby
# config/initializers/active_storage.rb
ActiveStorage::Service.register :custom, CustomStorageService
```

Use in storage.yml:

```yaml
custom:
  service: custom
  root: /var/storage
  bucket: my-bucket
  region: us-east-1
  url_base: https://storage.example.com
```

## Image Processing Pipeline

Optimize image processing for high-volume sites:

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.variant_processor = :vips

# Custom variant processor
class OptimizedVariantProcessor
  def self.process(blob, variant)
    case blob.content_type
    when /jpeg/
      process_jpeg(blob, variant)
    when /png/
      process_png(blob, variant)
    when /webp/
      process_webp(blob, variant)
    else
      blob.variant(variant)
    end
  end

  private
    def self.process_jpeg(blob, variant)
      # Optimize JPEG
      blob.variant(variant).tap do |v|
        v.options[:quality] = 75  # Balance quality/size
        v.options[:strip] = true  # Remove metadata
      end
    end

    def self.process_png(blob, variant)
      blob.variant(variant).tap do |v|
        v.options[:quality] = 9  # Max compression
        v.options[:strip] = true
      end
    end

    def self.process_webp(blob, variant)
      blob.variant(variant).tap do |v|
        v.options[:quality] = 80
      end
    end
end
```

## Monitoring & Analytics

Track storage usage and file access:

```ruby
# app/jobs/storage_analytics_job.rb
class StorageAnalyticsJob < ApplicationJob
  queue_as :default

  def perform
    stats = {
      timestamp: Time.current,
      total_blobs: ActiveStorage::Blob.count,
      total_size_bytes: ActiveStorage::Blob.sum(:byte_size),
      by_content_type: blobs_by_type,
      unattached_count: ActiveStorage::Blob.unattached.count,
      oldest_unattached: ActiveStorage::Blob.unattached.order(created_at: :asc).first&.created_at
    }

    # Send to monitoring service
    Datadog.distribution("active_storage.total_size", stats[:total_size_bytes])
    Datadog.gauge("active_storage.blob_count", stats[:total_blobs])
    Datadog.gauge("active_storage.unattached_count", stats[:unattached_count])

    # Log for analysis
    Rails.logger.info("Storage Analytics: #{stats}")
  end

  private
    def blobs_by_type
      ActiveStorage::Blob.group(:content_type)
                         .select("content_type, COUNT(*) as count, SUM(byte_size) as total_size")
                         .map { |b| { type: b.content_type, count: b.count, size: b.total_size } }
    end
end
```

Schedule regularly:

```ruby
# config/recurring.yml
storage_analytics:
  command: 'Rake.application.invoke_task("active_storage:analyze_storage")'
  schedule: 'every day at 00:00'
```

## Caching & Performance

### CDN Caching Headers

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.service_urls_expire_in = 7.days
```

Set cache-control headers in S3:

```yaml
amazon:
  service: S3
  # ...
  upload:
    cache_control: "public, max-age=<%= 1.year.to_i %>"  # 1 year for versioned assets
```

### In-Memory Caching

Cache frequently-accessed variants:

```ruby
# app/models/concerns/cached_variants.rb
module CachedVariants
  extend ActiveSupport::Concern

  def cached_variant(variant_name, expires_in: 1.day)
    cache_key = "attachment_variant:#{id}:#{variant_name}"
    
    Rails.cache.fetch(cache_key, expires_in: expires_in) do
      public_send(attachment_name).variant(variant_name).processed.url
    end
  end
end
```

Usage:

```ruby
class User < ApplicationRecord
  include CachedVariants
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
end

# In view
<%= image_tag @user.cached_variant(:thumb) %>
```

## Security & Validation

### File Type Validation

```ruby
# app/validators/file_type_validator.rb
class FileTypeValidator < ActiveModel::Validator
  ALLOWED_TYPES = {
    images: ["image/jpeg", "image/png", "image/gif", "image/webp"],
    documents: ["application/pdf", "application/msword"],
    video: ["video/mp4", "video/webm"]
  }.freeze

  def validate(record)
    options[:fields].each do |field|
      attachment = record.public_send(field)
      next unless attachment.attached?

      category = options[:type]
      allowed = ALLOWED_TYPES[category]

      unless allowed.include?(attachment.content_type)
        record.errors.add(field, "must be a valid #{category} file")
      end
    end
  end
end
```

Usage:

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  validates_with FileTypeValidator, fields: [:file], type: :documents
end
```

### Virus Scanning

```ruby
# app/jobs/virus_scan_job.rb
class VirusScanJob < ApplicationJob
  queue_as :default

  def perform(blob_id)
    blob = ActiveStorage::Blob.find(blob_id)
    
    blob.open do |file|
      result = ClamAV.scan_file(file.path)
      
      if result.virus?
        blob.purge
        # Notify admin
        AdminMailer.virus_detected(blob).deliver_later
      end
    end
  end
end
```

Trigger after upload:

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  after_create_commit :scan_for_viruses
  
  private
    def scan_for_viruses
      VirusScanJob.perform_later(file.blob.id)
    end
end
```

## Backup & Recovery

### Backup to Secondary Service

```ruby
# lib/tasks/backup_storage.rake
namespace :active_storage do
  desc "Backup blobs to secondary service"
  task backup_blobs: :environment do
    primary = ActiveStorage::Blob.service
    backup = ActiveStorage::Service.configure(:backup_s3, {})

    ActiveStorage::Blob.find_each do |blob|
      puts "Backing up #{blob.filename}..."
      
      primary.open(blob.key) do |file|
        backup.upload(blob.key, file)
      end
    end
  end
end
```

### Verify Integrity

```ruby
# app/jobs/integrity_check_job.rb
class IntegrityCheckJob < ApplicationJob
  def perform
    errors = []

    ActiveStorage::Blob.find_each do |blob|
      begin
        content = blob.service.download(blob.key)
        
        # Verify checksum
        actual_checksum = Digest::MD5.hexdigest(content)
        if actual_checksum != blob.checksum
          errors << "Checksum mismatch: #{blob.filename}"
        end
      rescue => e
        errors << "Error reading #{blob.filename}: #{e.message}"
      end
    end

    if errors.any?
      AdminMailer.integrity_check_failed(errors).deliver_later
    end
  end
end
```

## Rate Limiting & Quotas

Limit file uploads per user:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :documents
  
  def storage_quota_bytes
    10.gigabytes
  end

  def used_storage_bytes
    documents.joins(:file_attachment, :file_blob)
             .sum("active_storage_blobs.byte_size")
  end

  def storage_remaining_bytes
    storage_quota_bytes - used_storage_bytes
  end

  def can_upload?(file_size)
    file_size <= storage_remaining_bytes
  end
end
```

Usage in controller:

```ruby
class DocumentsController < ApplicationController
  def create
    @document = current_user.documents.build(document_params)

    unless current_user.can_upload?(@document.file.byte_size)
      @document.errors.add(:file, "exceeds storage quota")
      render :new and return
    end

    @document.save
  end
end
```

## Database Optimization

### Index for Performance

```ruby
# config/initializers/active_storage.rb
# Add indexes to active_storage_blobs
class AddIndexesToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def change
    add_index :active_storage_blobs, :content_type
    add_index :active_storage_blobs, :created_at
    add_index :active_storage_attachments, [:record_type, :record_id]
    add_index :active_storage_attachments, [:blob_id, :created_at]
  end
end
```

### Archive Old Files

```ruby
# lib/tasks/archive_old_files.rake
namespace :active_storage do
  desc "Archive files older than 1 year"
  task archive_old_files: :environment do
    cutoff_date = 1.year.ago
    
    old_blobs = ActiveStorage::Blob.where("created_at <= ?", cutoff_date)
    
    old_blobs.find_each do |blob|
      # Move to archive storage
      content = blob.service.download(blob.key)
      archive_service = ActiveStorage::Service.configure(:archive_s3, {})
      archive_service.upload("archive/#{blob.key}", StringIO.new(content))
      
      # Update blob reference
      blob.update(service_name: :archive_s3)
    end
  end
end
```
