# Serving & Transforming Files

This guide covers generating URLs, serving files, transforming images, creating previews, and integrating with CDNs.

## URL Generation

### Permanent URLs (Signed IDs)

Generate a permanent URL with a signed ID valid for the file's lifetime:

```ruby
url_for(user.avatar)
# => https://www.example.com/rails/active_storage/blobs/redirect/:signed_id/avatar.png
```

This URL can be safely shared and doesn't expire. The blob can be deleted independently of the URL.

### Redirect URLs

Create a download link that redirects to the file:

```ruby
rails_blob_path(user.avatar)
# => /rails/active_storage/blobs/redirect/:signed_id/avatar.png

rails_blob_url(user.avatar)
# => https://www.example.com/rails/active_storage/blobs/redirect/:signed_id/avatar.png
```

### Download Attachment

Force download instead of display (sets Content-Disposition: attachment):

```ruby
rails_blob_path(user.avatar, disposition: "attachment")
rails_blob_path(user.avatar, disposition: "inline")
```

Use in links:

```erb
<%= link_to "Download", rails_blob_path(user.avatar, disposition: "attachment") %>
```

### URL with Filename

Ensure the correct filename in the response:

```ruby
rails_blob_path(user.avatar, filename: "my-avatar.png")
```

## Serving Modes

Active Storage supports two modes for serving files.

### Redirect Mode (Default)

The app generates a signed URL that redirects to the storage service:

```ruby
# config/environments/production.rb
# config.active_storage.resolve_model_to_route = :rails_storage_redirect (default)
```

Benefits:
- Reduces server load (files served from storage)
- Works with any storage service
- URLs expire in 5 minutes for security

```erb
<img src="<%= url_for(product.image) %>" />
```

### Proxy Mode

The app downloads from storage and serves through your server:

```ruby
# config/environments/production.rb
config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

Or use explicitly:

```ruby
rails_storage_proxy_path(user.avatar)
rails_storage_proxy_url(user.avatar)
```

Benefits:
- Permanent URLs (no expiration)
- Better for CDN caching
- More control over access

```erb
<img src="<%= rails_storage_proxy_path(product.image) %>" />
```

## Image Variants (Transformations)

### Define Variants in Model

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [400, 400]
    attachable.variant :large, resize_to_limit: [1200, 1200]
  end
end
```

### Use Variants in Views

```erb
<!-- Lazy loading (default) -->
<%= image_tag user.avatar.variant(:thumb) %>

<!-- Immediate loading -->
<%= image_tag user.avatar.variant(:thumb).processed.url %>

<!-- Direct transformation -->
<%= image_tag user.avatar.variant(resize_to_limit: [200, 200]) %>
```

### Image Variant Options

#### Resize Operations

```ruby
# Resize to fit within dimensions, maintaining aspect ratio
resize_to_limit: [100, 100]

# Resize to exact dimensions, cropping if needed
resize_to_fill: [100, 100]

# Resize to exact dimensions, with padding
resize_to_fill: [100, 100], gravity: "center", background: "white"

# Resize proportionally to width, maintaining aspect ratio
resize_to_width: 200

# Resize proportionally to height
resize_to_height: 200

# Resize by percentage
resize: "50%"
```

#### Quality & Format

```ruby
# Set JPEG quality (0-100)
variant(resize_to_limit: [100, 100], quality: 85)

# Convert to different format
variant(format: "webp")
variant(format: "jpeg")
variant(format: "png")
variant(format: "avif")
```

#### Rotation & Flipping

```ruby
# Rotate by degrees
rotate: 90

# Flip horizontally
flip: "h"

# Flip vertically
flip: "v"

# Auto-rotate based on EXIF
auto_orient: true
```

#### Cropping & Gravity

```ruby
# Crop from specific corner
crop: "10x10+50+100"  # width x height + offset_x + offset_y

# Use gravity to crop from center
gravity: "center"

# Strip metadata
strip: true
```

### Performance: Preprocessed Variants

Generate variants immediately after upload instead of on-demand:

```ruby
class Product < ApplicationRecord
  has_many_attached :images do |attachable|
    attachable.variant :display, resize_to_limit: [800, 600], preprocessed: true
  end
end
```

Rails enqueues a job to create variants automatically:

```ruby
# In job
ProductImageVariantJob.perform_later(product.id)
```

### Variant Tracking

Improve performance by tracking which variants have been generated:

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.track_variants = true  # Default

# Use preloaded variant records to avoid N+1
posts = Post.includes(:images_attachments, :images_blobs)
             .with_all_variant_records

posts.each do |post|
  post.images.each do |image|
    # No N+1 query here
    puts image.variant(:thumb).processed.url
  end
end
```

## File Previews

### Preview Non-Image Files

Generate a preview image for videos and PDFs:

```ruby
class Post < ApplicationRecord
  has_one_attached :video do |attachable|
    # Create thumbnail preview
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  
  has_one_attached :document
end
```

In views:

```erb
<!-- Video preview (extracts first frame) -->
<%= image_tag post.video.preview(resize_to_limit: [200, 200]) %>

<!-- PDF preview (extracts first page) -->
<%= image_tag post.document.preview(resize_to_limit: [200, 200]) %>
```

### Check if File is Representable

```ruby
if post.document.representable?
  <%= image_tag post.document.representation(resize_to_limit: [200, 200]) %>
else
  <%= link_to "Download", rails_blob_path(post.document) %>
end
```

### representation Method (Generic)

Use `representation` for any blob type (calls `variant` for images, `preview` for others):

```ruby
<%= image_tag post.file.representation(resize_to_limit: [100, 100]) %>
```

## CDN Integration

### Proxy Mode with CDN

Configure CDN to cache proxied responses:

```ruby
# config/environments/production.rb
config.active_storage.resolve_model_to_route = :rails_storage_proxy
config.action_controller.asset_host = "https://cdn.example.com"
```

### Custom CDN Routes

Map custom routes to CDN:

```ruby
# config/routes.rb
direct :cdn_image do |model, options|
  expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }

  if model.respond_to?(:signed_id)
    route_for(
      :rails_service_blob_proxy,
      model.signed_id(expires_in: expires_in),
      model.filename,
      options.merge(host: ENV["CDN_HOST"])
    )
  else
    signed_blob_id = model.blob.signed_id(expires_in: expires_in)
    variation_key  = model.variation.key
    filename       = model.blob.filename

    route_for(
      :rails_blob_representation_proxy,
      signed_blob_id,
      variation_key,
      filename,
      options.merge(host: ENV["CDN_HOST"])
    )
  end
end
```

Use in views:

```erb
<%= image_tag cdn_image_url(user.avatar.variant(resize_to_limit: [128, 128])) %>
```

## Authenticated Controllers

Protect file access by implementing custom controllers.

### Create Custom Controller

```ruby
# app/controllers/authenticated_files_controller.rb
class AuthenticatedFilesController < ActiveStorage::Blobs::ProxyController
  include Authenticate

  def show
    # Check authorization
    redirect_to_blob unless authorized_to_access_blob?
  end

  private
    def redirect_to_blob
      super
    end

    def authorized_to_access_blob?
      blob = ActiveStorage::Blob.find_signed(params[:signed_id])
      current_user.admin? || blob.record.owner_id == current_user.id
    end
end
```

### Disable Default Routes

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.draw_routes = false
```

### Add Custom Routes

```ruby
# config/routes.rb
resource :account do
  resource :logo, controller: :authenticated_files
end
```

## Common Patterns

### Display User Avatar

```erb
<% if current_user.avatar.attached? %>
  <%= image_tag current_user.avatar.variant(resize_to_limit: [150, 150]),
                 class: "user-avatar" %>
<% else %>
  <%= image_tag "default-avatar.png", class: "user-avatar" %>
<% end %>
```

### Photo Gallery

```erb
<div class="gallery">
  <% @post.images.each do |image| %>
    <div class="photo">
      <%= link_to image_tag(image.variant(resize_to_limit: [200, 200])),
                   image_tag(image.variant(resize_to_limit: [800, 600])),
                   data: { lightbox: true } %>
    </div>
  <% end %>
</div>
```

### Responsive Images

```erb
<picture>
  <source srcset="<%= url_for(user.avatar.variant(resize_to_fill: [400, 400], format: 'webp')) %>" type="image/webp">
  <source srcset="<%= url_for(user.avatar.variant(resize_to_fill: [400, 400])) %>" type="image/jpeg">
  <%= image_tag user.avatar, alt: "User avatar", class: "avatar" %>
</picture>
```

### Optimization

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.variable_content_types += ["application/pdf"]
Rails.application.config.active_storage.previewable_content_types += ["application/vnd.ms-excel"]

# Use efficient variant processor
Rails.application.config.active_storage.variant_processor = :vips  # or :mini_magick
```
