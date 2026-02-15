# Attaching Files to Models

This guide covers the different ways to attach files to Active Record models using `has_one_attached` and `has_many_attached`.

## has_one_attached (Single File)

Use `has_one_attached` when a model has exactly one file of a given type.

### Basic Definition

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end
```

### Create User with Avatar

In controller:

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

In view:

```erb
<%= form_with model: @user, local: true do |form| %>
  <%= form.text_field :name %>
  <%= form.email_field :email %>
  <%= form.file_field :avatar, direct_upload: true %>
  <%= form.submit "Create User" %>
<% end %>
```

### Attach to Existing User

```ruby
user = User.find(1)
user.avatar.attach(params[:avatar])
```

Or attach from URL/file:

```ruby
# Attach from file system
user.avatar.attach(io: File.open("/path/to/avatar.png"), filename: "avatar.png")

# Attach from URL
require "open-uri"
user.avatar.attach(io: URI.open("https://example.com/avatar.png"), filename: "avatar.png")
```

### Check if Attached

```ruby
user.avatar.attached?  # => true or false
user.avatar.attached?  # => true
```

### Access Attachment Metadata

```ruby
user.avatar.filename           # => "avatar.png"
user.avatar.content_type       # => "image/png"
user.avatar.byte_size          # => 125000
user.avatar.created_at         # => 2024-01-15 10:30:00
user.avatar.checksum           # => "rN7QgP..."
user.avatar.metadata[:height]  # => 800
user.avatar.metadata[:width]   # => 600
```

## has_many_attached (Multiple Files)

Use `has_many_attached` when a model can have many files.

### Basic Definition

```ruby
class Message < ApplicationRecord
  has_many_attached :images
end
```

### Create Message with Images

```ruby
class MessagesController < ApplicationController
  def create
    @message = Message.create!(message_params)
    redirect_to @message
  end

  private
    def message_params
      params.expect(message: [:title, :content, images: []])
    end
end
```

In view:

```erb
<%= form_with model: @message, local: true do |form| %>
  <%= form.text_field :title %>
  <%= form.text_area :content %>
  <%= form.file_field :images, multiple: true, direct_upload: true %>
  <%= form.submit "Create Message" %>
<% end %>
```

### Attach Multiple Files

```ruby
message = Message.find(1)
message.images.attach(params[:images])

# Attach from array
message.images.attach([
  { io: File.open("image1.jpg"), filename: "image1.jpg" },
  { io: File.open("image2.jpg"), filename: "image2.jpg" }
])
```

### Check if Attachments Exist

```ruby
message.images.attached?  # => true or false
message.images.count      # => 3
message.images.any?       # => true
message.images.empty?     # => false
```

### Iterate Over Attachments

```ruby
message.images.each do |image|
  puts image.filename
  puts image.content_type
  puts image.byte_size
end
```

### Accessing Individual Attachments

```ruby
first_image = message.images.first
last_image = message.images.last
second_image = message.images[1]
```

## Attaching File/IO Objects

Attach files directly using IO objects instead of form uploads.

### From File System

```ruby
user.avatar.attach(
  io: File.open("/path/to/file.jpg"),
  filename: "my-avatar.jpg",
  content_type: "image/jpeg"
)
```

### From URL

```ruby
require "open-uri"

user.avatar.attach(
  io: URI.open("https://example.com/image.jpg"),
  filename: "downloaded-image.jpg",
  content_type: "image/jpeg"
)
```

### From StringIO (Generated Content)

```ruby
require "stringio"

image_data = generate_qr_code("https://example.com")  # Returns image bytes
user.avatar.attach(
  io: StringIO.new(image_data),
  filename: "qr-code.png",
  content_type: "image/png"
)
```

### Specify S3 Key/Path

```ruby
user.avatar.attach(
  io: File.open("/path/to/file"),
  filename: "avatar.jpg",
  key: "users/#{user.id}/avatar.jpg"  # Custom S3 path
)
```

Or with randomized key for uniqueness:

```ruby
user.avatar.attach(
  io: File.open("/path/to/file"),
  filename: "avatar.jpg",
  key: "users/#{user.id}/avatar-#{SecureRandom.uuid}.jpg"
)
```

### Bypass Content Type Detection

```ruby
user.avatar.attach(
  io: File.open("/path/to/file"),
  filename: "document.pdf",
  content_type: "application/pdf",
  identify: false  # Skip automatic content type detection
)
```

## Replacing vs Adding Attachments

### has_one_attached (Replace)

By default, attaching a new file replaces the old one:

```ruby
user.avatar.attach(new_file)  # Old avatar is deleted
```

### has_many_attached (Replace by Default)

By default, attaching new files replaces all existing ones:

```ruby
message.images.attach(new_images)  # All old images are deleted
```

Keep existing attachments by storing signed IDs:

```erb
<% @message.images.each do |image| %>
  <%= form.hidden_field :images, multiple: true, value: image.signed_id %>
<% end %>

<%= form.file_field :images, multiple: true %>
```

## Form Validation

Attachments aren't saved to storage until the record is saved. If validation fails, uploads are lost.

Use direct uploads to retain files when validation fails:

```erb
<%= form_with model: @user, local: true do |form| %>
  <% if @user.errors.any? %>
    <div class="error">
      <%= @user.errors.full_messages.join(", ") %>
    </div>
  <% end %>

  <%= form.text_field :name %>
  <%= form.email_field :email %>
  
  <!-- Keep uploaded avatar if validation fails -->
  <% if @user.avatar.attached? %>
    <%= form.hidden_field :avatar, value: @user.avatar.signed_id %>
  <% end %>
  
  <%= form.file_field :avatar, direct_upload: true %>
  <%= form.submit "Create User" %>
<% end %>
```

## Configuring Attachment Options

### Service per Attachment

Store different attachments in different cloud services:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar, service: :s3
  has_one_attached :backup_avatar, service: :gcs
end
```

### Variants per Attachment

Define image variants at the model level:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [400, 400]
    attachable.variant :large, resize_to_limit: [1200, 1200]
  end
end
```

Usage:

```ruby
user.avatar.variant(:thumb)   # 100x100
user.avatar.variant(:medium)  # 400x400
```

### Preprocessed Variants

Generate variants immediately after attachment (instead of lazy):

```ruby
class Product < ApplicationRecord
  has_many_attached :images do |attachable|
    attachable.variant :display, resize_to_limit: [800, 600], preprocessed: true
  end
end
```

## Type Validation

Validate file types at the model level:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  
  validate :avatar_content_type, if: -> { avatar.attached? }
  
  private
    def avatar_content_type
      allowed_types = ["image/jpeg", "image/png", "image/gif"]
      return if allowed_types.include?(avatar.content_type)
      
      errors.add(:avatar, "must be a valid image format (JPG, PNG, GIF)")
    end
end
```

Or use validators gem:

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  validates :file, attached: true, size: { less_than: 10.megabytes },
                    content_type: { in: "application/pdf" }
end
```

## Size Validation

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  
  validate :avatar_size, if: -> { avatar.attached? }
  
  private
    def avatar_size
      return if avatar.byte_size <= 5.megabytes
      
      errors.add(:avatar, "must be less than 5MB")
    end
end
```
