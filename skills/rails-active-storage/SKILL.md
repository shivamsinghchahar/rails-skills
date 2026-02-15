---
name: rails-active-storage
description: Master Rails Active Storage for file attachments, cloud storage integration, image transformations, and direct uploads. Use when implementing file uploads, managing attachments to records, configuring S3/GCS storage, generating image variants, and handling file analysis. Covers local disk, cloud services, direct uploads, and advanced patterns.
---

# Rails Active Storage

Active Storage provides a framework for attaching files to Active Record models through cloud storage services like Amazon S3, Google Cloud Storage, or local disk storage. It handles file uploads, transformations, previews, and lifecycle management with minimal configuration.

## When to Use Active Storage

- **File attachments**: Attach avatars, documents, media files to models
- **Cloud storage integration**: Configure S3, Google Cloud Storage, or other services
- **Image processing**: Generate thumbnails, resize images, create variants
- **File analysis**: Extract metadata from images, videos, and PDFs
- **Direct uploads**: Allow users to upload directly to cloud storage
- **File serving**: Redirect or proxy files with signed URLs
- **Multi-service support**: Mirror files across multiple storage backends
- **Testing**: Use disk storage for development and testing

## Quick Start

### 1. Installation & Setup

```bash
# Generate migrations and set up storage tables
rails active_storage:install
rails db:migrate
```

Configure storage services in `config/storage.yml`:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: my-app-<%= Rails.env %>

google:
  service: GCS
  credentials: <%= Rails.root.join("path/to/keyfile.json") %>
  project: my-project
  bucket: my-app-<%= Rails.env %>
```

Set the default service in `config/environments/development.rb`:

```ruby
config.active_storage.service = :local
```

### 2. Attach Files to Models

#### Single File Attachment (has_one_attached)

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end
```

Use in forms:

```erb
<%= form.file_field :avatar, direct_upload: true %>
```

Handle in controller:

```ruby
class UsersController < ApplicationController
  def create
    @user = User.create!(user_params)
    redirect_to @user
  end

  private
    def user_params
      params.expect(user: [:name, :email, :avatar])
    end
end
```

Attach to existing records:

```ruby
user.avatar.attach(params[:avatar])
user.avatar.attached?  # => true
```

#### Multiple File Attachments (has_many_attached)

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

Attach multiple files:

```ruby
@message.images.attach(params[:images])
@message.images.attached?  # => true
```

### 3. Serve Files

Generate permanent URLs:

```ruby
url_for(user.avatar)
# => https://www.example.com/rails/active_storage/blobs/redirect/:signed_id/avatar.png

rails_blob_path(user.avatar, disposition: "attachment")
# => Download link
```

Display in views:

```erb
<%= image_tag user.avatar %>
<%= link_to "Download", rails_blob_path(user.avatar, disposition: "attachment") %>
```

### 4. Transform Images

Create variants with on-demand transformation:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
end
```

Use variants in views:

```erb
<%= image_tag user.avatar.variant(:thumb) %>
```

### 5. Remove Files

Synchronously delete files:

```ruby
user.avatar.purge       # Synchronous
user.avatar.purge_later # Async via Active Job
```

## Core Topics

**Setup & Configuration**: See [setup-and-configuration.md](setup-and-configuration.md) for disk and cloud service setup, environment configuration, and credentials management.

**Attaching Files**: See [attaching-files.md](attaching-files.md) for `has_one_attached`, `has_many_attached`, attaching file/IO objects, form handling, and validation strategies.

**File Operations**: See [file-operations.md](file-operations.md) for querying attachments, removing files, downloading file contents, analyzing files, and handling blob metadata.

**Serving & Transformations**: See [serving-and-transformations.md](serving-and-transformations.md) for URL generation, redirect vs proxy modes, image variants, previews, and CDN integration.

**Direct Uploads**: See [direct-uploads.md](direct-uploads.md) for client-side uploads, CORS configuration, JavaScript events, and integrating with upload libraries.

**Testing**: See [testing.md](testing.md) for test configuration, file fixtures, cleaning up test files, and mocking storage services.

**Advanced Patterns**: See [references/REFERENCE.md](references/REFERENCE.md) for production deployments, multiple databases, mirror services, implementing custom services, and real-world examples.

## Examples

See [examples.md](examples.md) for practical implementations including:
- User profile with avatar and gallery
- Document management with file analysis
- Media library with transformations
- Direct upload with progress tracking
- Custom authenticated file serving

## Key Concepts

### Blobs
Blobs represent files stored in your service. Each blob has:
- `filename` — the original file name
- `content_type` — MIME type (image/png, application/pdf, etc.)
- `byte_size` — file size in bytes
- `checksum` — content hash for integrity verification
- `metadata` — custom key-value data

### Attachments
Attachments are polymorphic join records connecting models to blobs:
- Enable one-to-one relationships with `has_one_attached`
- Enable one-to-many relationships with `has_many_attached`
- Automatically handle file lifecycle with dependent destroy

### Variants
Variants are processed representations of blobs:
- Transform images on-demand (resize, crop, format conversion)
- Lazy-loaded by default for performance
- Supports ImageMagick and libvips processors
- Can be pre-generated for frequently-accessed images

### Direct Uploads
Direct uploads bypass your application servers:
- Files upload directly to cloud storage
- Reduces server load and bandwidth
- Retains uploads when form validation fails
- Requires CORS configuration on cloud storage

## Common Patterns

### Avatar Management
```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :medium, resize_to_limit: [400, 400]
    attachable.variant :thumb, resize_to_limit: [150, 150]
  end
  
  validate :avatar_content_type
  
  private
    def avatar_content_type
      return unless avatar.attached?
      unless avatar.content_type.in?(%w[image/jpeg image/png image/gif])
        errors.add(:avatar, "must be a valid image")
      end
    end
end
```

### Document Upload with Analysis
```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  after_create_commit :analyze_document
  
  private
    def analyze_document
      return unless file.attached?
      puts "File: #{file.filename}"
      puts "Size: #{file.byte_size} bytes"
      puts "Type: #{file.content_type}"
      puts "Analyzed: #{file.analyzed?}"
      # Use metadata from file.metadata for further processing
    end
end
```

### Image Gallery
```ruby
class Post < ApplicationRecord
  has_many_attached :images do |attachable|
    attachable.variant :display, resize_to_limit: [800, 600]
    attachable.variant :thumb, resize_to_limit: [200, 200]
  end
end

# In view:
<%= @post.images.each do |image| %>
  <%= image_tag image.variant(:display) %>
<% end %>
```

### Querying Attachments
```ruby
# Find users with avatars
User.joins(:avatar_attachment).distinct

# Find messages with only video attachments
Message.joins(:images_blobs).where(active_storage_blobs: { content_type: "video/mp4" })

# Eager load to prevent N+1
Post.includes(:images_attachments, :images_blobs)
```

## Important Notes

- **Requirements**: Image processing requires libvips or ImageMagick; video/PDF processing needs ffmpeg and poppler
- **Credentials**: Use Rails credentials (`rails credentials:edit`) to manage AWS/GCS keys
- **Storage Isolation**: Use Rails.env in bucket names to prevent accidental data loss
- **Direct Upload Safety**: Validate file types and sizes on both client and server
- **Testing**: Configure `config/storage/test.yml` to use disk service instead of cloud storage
- **N+1 Queries**: Use eager loading with `includes(:*_attachments, :*_blobs)` when displaying multiple attachments
