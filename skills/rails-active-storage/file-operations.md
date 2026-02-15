# File Operations: Querying, Removing, Downloading

This guide covers querying attachments, removing files, downloading content, and analyzing file metadata.

## Querying Attachments

### Basic Queries

```ruby
# Check if attachment exists
user.avatar.attached?  # => true or false

# Get attachment count
message.images.count   # => 3

# Check if has attachments
message.images.any?    # => true
message.images.empty?  # => false
```

### Querying Models with Attachments

Find all users with avatars:

```ruby
User.joins(:avatar_attachment).distinct
```

Find users without avatars:

```ruby
User.left_joins(:avatar_attachment)
    .where(active_storage_attachments: { id: nil })
```

Find messages with specific image types:

```ruby
Message.joins(:images_blobs)
        .where(active_storage_blobs: { content_type: "image/png" })
```

Find messages with video attachments:

```ruby
Message.joins(:images_blobs)
        .where(active_storage_blobs: { content_type: ["video/mp4", "video/webm"] })
```

### Eager Loading

Prevent N+1 queries when accessing attachments:

```ruby
# Load all images and metadata for each message
messages = Message.includes(:images_attachments, :images_blobs)

messages.each do |message|
  message.images.each do |image|
    puts image.filename
    puts image.content_type
  end
end
```

Load all variants too:

```ruby
messages = Message.includes(:images_attachments, :images_blobs)
                   .with_all_variant_records
```

## Removing Files

### Synchronous Deletion

Delete a file immediately:

```ruby
# Delete single attachment
user.avatar.purge

# Delete all attachments
message.images.purge
```

This removes:
- The blob from storage
- The attachment record from the database
- The actual file from the storage service

### Asynchronous Deletion

Delete in background using Active Job:

```ruby
user.avatar.purge_later
message.images.purge_later
```

Or with delay:

```ruby
user.avatar.purge_later(wait: 1.hour)
```

### Delete When Record Destroyed

Configure automatic cleanup:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar, dependent: :destroy
end

class Message < ApplicationRecord
  has_many_attached :images, dependent: :destroy
end
```

With `dependent: :destroy`:
- Files are automatically purged when the record is destroyed
- This triggers Active Job for async deletion
- Use `dependent: :delete` for synchronous deletion

## Downloading Files

### Download File Content

Read file into memory:

```ruby
binary_data = user.avatar.download
# binary_data is the entire file content as bytes
```

### Process Large Files

Use a temporary file for large files to avoid memory issues:

```ruby
message.video.open do |file|
  # file is a temporary File object
  puts file.path
  
  # Process the file
  system "ffmpeg -i #{file.path} -f null -"
  
  # File is automatically deleted when block ends
end
```

### Download to Disk

```ruby
user.avatar.open do |file|
  File.binwrite("/tmp/avatar_backup.png", file.read)
end
```

### Stream to HTTP Response

```ruby
class FilesController < ApplicationController
  def download
    @document = Document.find(params[:id])
    
    send_data @document.file.download,
              filename: @document.file.filename.to_s,
              type: @document.file.content_type,
              disposition: "attachment"
  end
end
```

## Analyzing Files

### Automatic Analysis

Files are analyzed after upload via Active Job:

```ruby
class Product < ApplicationRecord
  has_one_attached :image
  
  after_create_commit :log_image_metadata
  
  private
    def log_image_metadata
      return unless image.attached?
      puts "File: #{image.filename}"
      puts "Type: #{image.content_type}"
      puts "Size: #{image.byte_size} bytes"
    end
end
```

### Check Analysis Status

```ruby
image = product.image
image.analyzed?          # => true or false
image.analysis_errors    # => Array of error messages

# Wait for analysis
image.open do |file|
  until image.analyzed?
    sleep 0.1
  end
  
  # Access metadata
  puts image.metadata[:width]
  puts image.metadata[:height]
end
```

### Image Metadata

After analysis, images have metadata:

```ruby
image = product.image

if image.analyzed?
  puts image.metadata[:width]      # => 1200
  puts image.metadata[:height]     # => 800
  puts image.metadata[:identified] # => true
end
```

### Video Metadata

```ruby
video = post.video

if video.analyzed?
  puts video.metadata[:duration]          # => 42.5 (seconds)
  puts video.metadata[:angle]             # => 0 or 90 (rotation)
  puts video.metadata[:video]             # => true (has video stream)
  puts video.metadata[:audio]             # => true (has audio stream)
  puts video.metadata[:display_aspect_ratio] # => "16:9"
end
```

### Audio Metadata

```ruby
audio = podcast.file

if audio.analyzed?
  puts audio.metadata[:duration]  # => 3600.5 (seconds)
  puts audio.metadata[:bit_rate]  # => 128000 (bits per second)
end
```

### Custom Metadata

Store custom metadata with attachments:

```ruby
image = product.image
image.metadata["uploaded_by"] = current_user.email
image.metadata["category"] = "product-photo"
image.update(metadata: image.metadata)
```

## Blob Operations

Access underlying blob objects:

```ruby
# Single attachment
user.avatar_blob     # => ActiveStorage::Blob instance
user.avatar.blob     # => Same thing

# Multiple attachments
message.images_blobs  # => Collection of blobs
message.images.map(&:blob)
```

### Blob Properties

```ruby
blob = user.avatar.blob

blob.id              # => UUID
blob.key             # => Random key in storage
blob.filename        # => "avatar.png"
blob.content_type    # => "image/png"
blob.byte_size       # => 125000
blob.checksum        # => "rN7QgP..."
blob.created_at      # => 2024-01-15 10:30:00
blob.metadata        # => Custom metadata hash
blob.analyzed?       # => true or false
```

### Signed IDs

Generate time-limited, tamper-proof identifiers:

```ruby
blob = user.avatar.blob

# Default expires in 1 hour
signed_id = blob.signed_id

# Custom expiration
signed_id = blob.signed_id(expires_in: 7.days)

# Find blob from signed ID
blob = ActiveStorage::Blob.find_signed(signed_id)
blob = ActiveStorage::Blob.find_signed(signed_id, expires_in: 7.days)
```

Use in forms to retain attachments during validation:

```erb
<% if @user.avatar.attached? %>
  <%= form.hidden_field :avatar, value: @user.avatar.signed_id %>
<% end %>
```

## Bulk Operations

### Purge Multiple Files by Age

```ruby
# Delete all unattached blobs older than 2 days
ActiveStorage::Blob.unattached
                   .where("created_at <= ?", 2.days.ago)
                   .find_each(&:purge_later)
```

Add to `lib/tasks/active_storage.rake`:

```ruby
namespace :active_storage do
  desc "Purges unattached blobs older than 2 days"
  task purge_unattached: :environment do
    ActiveStorage::Blob.unattached
                       .where("created_at <= ?", 2.days.ago)
                       .find_each(&:purge_later)
  end
end
```

### Count Attachments

```ruby
# Total blobs
ActiveStorage::Blob.count

# By content type
ActiveStorage::Blob.group(:content_type).count

# By service
ActiveStorage::Blob.select("key, COUNT(*) as count")
                   .group(:service_name)
```

### Storage Usage

```ruby
total_size = ActiveStorage::Blob.sum(:byte_size)
total_size_mb = total_size / (1024 * 1024).to_f

puts "Total storage: #{total_size_mb.round(2)} MB"

# By model
User.joins(:avatar_attachment, :avatar_blob)
    .select("SUM(active_storage_blobs.byte_size) as total_size")
    .group("users.id")
    .map { |u| [u.id, (u.total_size / (1024 * 1024)).round(2)] }
```

## Error Handling

### Handle Missing Files

```ruby
begin
  content = user.avatar.download
rescue ActiveStorage::FileNotFoundError
  puts "File not found in storage"
  user.avatar.purge  # Clean up orphaned attachment
end
```

### Handle Virus Scan Results

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  after_create_commit :scan_for_viruses
  
  private
    def scan_for_viruses
      return unless file.attached?
      
      begin
        # Call your virus scanner
        result = VirusScanner.scan(file.download)
        
        if result.infected?
          file.purge
          raise "File contains malware"
        end
      rescue => e
        puts "Virus scan failed: #{e.message}"
      end
    end
end
```
