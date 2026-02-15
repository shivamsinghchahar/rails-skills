# Setup & Configuration

This guide covers installing and configuring Active Storage for your Rails application.

## Installation

Generate the necessary migrations and database tables:

```bash
rails active_storage:install
rails db:migrate
```

This creates three tables:
- `active_storage_blobs` — stores file metadata (name, content type, size, checksum)
- `active_storage_attachments` — polymorphic join table connecting models to blobs
- `active_storage_variant_records` — tracks generated image variants for performance

## Configuring Storage Services

All storage services are configured in `config/storage.yml`. Each service has a name and configuration specific to its type.

### Disk Service (Local Storage)

Best for development and testing:

```yaml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>
```

### Amazon S3 Service

For production deployments:

```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: my-app-<%= Rails.env %>
```

Set credentials using Rails credentials:

```bash
rails credentials:edit
# Add to credentials.yml.enc:
aws:
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
```

#### S3 Options

```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: my-app-<%= Rails.env %>
  http_open_timeout: 0
  http_read_timeout: 0
  retry_limit: 0
  upload:
    server_side_encryption: AES256
    cache_control: "private, max-age=<%= 1.day.to_i %>"
```

#### IAM Policy (Minimum Permissions)

For least-privilege access, create an IAM user with these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ]
    }
  ]
}
```

#### S3-Compatible Services

For DigitalOcean Spaces or other S3-compatible APIs:

```yaml
digitalocean:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:digitalocean, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:digitalocean, :secret_access_key) %>
  endpoint: https://nyc3.digitaloceanspaces.com
  bucket: my-app-<%= Rails.env %>
  region: nyc3
```

### Google Cloud Storage Service

```yaml
google:
  service: GCS
  credentials: <%= Rails.root.join("path/to/keyfile.json") %>
  project: my-project-id
  bucket: my-app-<%= Rails.env %>
```

Or using Rails credentials:

```yaml
google:
  service: GCS
  credentials:
    type: "service_account"
    project_id: "<%= Rails.application.credentials.dig(:gcs, :project_id) %>"
    private_key_id: "<%= Rails.application.credentials.dig(:gcs, :private_key_id) %>"
    private_key: "<%= Rails.application.credentials.dig(:gcs, :private_key).dump %>"
    client_email: "<%= Rails.application.credentials.dig(:gcs, :client_email) %>"
  bucket: my-app-<%= Rails.env %>
  cache_control: "public, max-age=3600"
```

### Mirror Service (Sync to Multiple Services)

For migrating between storage providers:

```yaml
s3_primary:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: us-east-1
  bucket: my-app-<%= Rails.env %>

s3_backup:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws_backup, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws_backup, :secret_access_key) %>
  region: eu-west-1
  bucket: my-app-backup-<%= Rails.env %>

production:
  service: Mirror
  primary: s3_primary
  mirrors:
    - s3_backup
```

## Environment Configuration

Set the default storage service per environment:

```ruby
# config/environments/development.rb
config.active_storage.service = :local

# config/environments/test.rb
config.active_storage.service = :test

# config/environments/production.rb
config.active_storage.service = :amazon
```

Or use environment-specific storage config files (takes precedence):

```ruby
# config/storage/production.yml
amazon:
  service: S3
  # Production-specific config
```

## Credentials Management

### Setting AWS Credentials

```bash
rails credentials:edit
```

Add to the editor:

```yaml
aws:
  access_key_id: AKIAIOSFODNN7EXAMPLE
  secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

gcs:
  project_id: my-project-123456
  private_key_id: key-id-123
  private_key: |
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEF...
    -----END PRIVATE KEY-----
```

### Using Environment Variables

Instead of credentials, use environment variables:

```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI...
export AWS_REGION=us-east-1
```

Then in storage.yml:

```yaml
amazon:
  service: S3
  # AWS SDK automatically uses ENV variables
  bucket: my-app-<%= Rails.env %>
  region: <%= ENV["AWS_REGION"] %>
```

## Public vs Private Access

### Private Access (Default)

Files are protected with signed URLs that expire:

```yaml
amazon:
  service: S3
  bucket: my-app-<%= Rails.env %>
  # public: false (default)
```

### Public Access

Make files publicly readable:

```yaml
amazon_public:
  service: S3
  bucket: my-app-public-<%= Rails.env %>
  public: true
```

Usage:

```ruby
class BlogPost < ApplicationRecord
  has_one_attached :cover_image, service: :amazon_public
end
```

**Warning**: Ensure your bucket permissions allow public reads before enabling this.

## Image Processing Dependencies

### libvips (Recommended)

Fast image processing with minimal memory:

```bash
# macOS
brew install vips

# Ubuntu/Debian
sudo apt-get install libvips-dev

# Configure in Rails
Rails.application.config.active_storage.variant_processor = :vips
```

### ImageMagick (Alternative)

```bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick libmagickwand-dev

# Configure in Rails
Rails.application.config.active_storage.variant_processor = :mini_magick
```

### ffmpeg & poppler

For video previews and PDF processing:

```bash
# macOS
brew install ffmpeg poppler

# Ubuntu/Debian
sudo apt-get install ffmpeg poppler-utils
```

## Testing Configuration

Use disk service in test environment:

```yaml
# config/storage/test.yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

# Override cloud services for testing
s3:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>
```

Or configure in `config/environments/test.rb`:

```ruby
config.active_storage.service = :test
config.active_job.queue_adapter = :inline  # Process jobs immediately
```

## Database Configuration for UUIDs

If your models use UUIDs as primary keys:

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

Then generate migrations:

```bash
rails active_storage:install
rails db:migrate
```

## Troubleshooting

### Missing Image Processor

```
Error: Image processor not found
Solution: Install libvips or ImageMagick
```

### S3 Access Denied

```
Error: Aws::S3::Errors::AccessDenied
Solution: Check IAM credentials and bucket permissions
```

### Blob Not Found

```
Error: ActiveStorage::Blob not found
Solution: Check storage service configuration and blob ID
```
