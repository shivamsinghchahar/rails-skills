# Examples

Practical, real-world implementations of Active Storage patterns.

## Example 1: User Profile with Avatar

Simple user profile with single avatar attachment.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end

  validates :email, presence: true, uniqueness: true
  validate :avatar_content_type, if: -> { avatar.attached? }

  private
    def avatar_content_type
      allowed_types = ["image/jpeg", "image/png", "image/gif"]
      return if allowed_types.include?(avatar.content_type)
      
      errors.add(:avatar, "must be a JPEG, PNG, or GIF")
    end
end
```

```erb
<!-- app/views/users/edit.html.erb -->
<%= form_with model: @user, local: true do |form| %>
  <div class="form-group">
    <% if @user.avatar.attached? %>
      <%= form.hidden_field :avatar, value: @user.avatar.signed_id %>
      <div>Current avatar: <%= image_tag @user.avatar.variant(:thumb) %></div>
    <% end %>
    
    <%= form.file_field :avatar, accept: "image/*", direct_upload: true %>
    <small>JPG, PNG, or GIF up to 5MB</small>
  </div>

  <%= form.submit "Update Profile" %>
<% end %>
```

```erb
<!-- app/views/users/show.html.erb -->
<div class="profile">
  <% if @user.avatar.attached? %>
    <%= image_tag @user.avatar.variant(:medium), class: "profile-avatar" %>
  <% else %>
    <%= image_tag "default-avatar.png", class: "profile-avatar" %>
  <% end %>
  
  <h1><%= @user.name %></h1>
  <p><%= @user.email %></p>
</div>
```

## Example 2: Photo Gallery with Multiple Attachments

Blog post with photo gallery.

```ruby
# app/models/blog_post.rb
class BlogPost < ApplicationRecord
  has_many_attached :gallery_images do |attachable|
    attachable.variant :display, resize_to_limit: [800, 600]
    attachable.variant :thumb, resize_to_limit: [200, 150]
  end

  validates :title, :content, presence: true
  validate :gallery_images_content_type

  private
    def gallery_images_content_type
      return unless gallery_images.attached?

      gallery_images.each do |image|
        unless image.content_type.start_with?("image/")
          errors.add(:gallery_images, "must be valid images")
          break
        end
      end
    end
end
```

```erb
<!-- app/views/blog_posts/edit.html.erb -->
<%= form_with model: @post, local: true do |form| %>
  <%= form.text_field :title, placeholder: "Blog Title" %>
  <%= form.text_area :content, placeholder: "Blog Content" %>

  <fieldset>
    <legend>Gallery Images</legend>
    
    <!-- Preserve existing images -->
    <% @post.gallery_images.each do |image| %>
      <div class="image-item">
        <%= image_tag image.variant(:thumb) %>
        <label>
          <%= form.hidden_field :gallery_images, multiple: true, value: image.signed_id %>
          Keep
        </label>
      </div>
    <% end %>

    <!-- Add new images -->
    <div class="form-group">
      <%= form.file_field :gallery_images, multiple: true, 
                           accept: "image/*", direct_upload: true %>
    </div>
  </fieldset>

  <%= form.submit "Publish" %>
<% end %>
```

```erb
<!-- app/views/blog_posts/show.html.erb -->
<article>
  <h1><%= @post.title %></h1>
  <p><%= @post.content %></p>

  <% if @post.gallery_images.attached? %>
    <div class="photo-gallery">
      <% @post.gallery_images.each do |image| %>
        <div class="photo-item">
          <a href="<%= url_for(image) %>" data-lightbox="gallery">
            <%= image_tag image.variant(:thumb), alt: "Gallery image" %>
          </a>
        </div>
      <% end %>
    </div>
  <% end %>
</article>
```

## Example 3: Document Management with Metadata

Upload documents and extract metadata.

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  validates :title, presence: true
  validate :file_type_and_size

  after_create_commit :analyze_document

  def file_type
    file.content_type if file.attached?
  end

  def file_size_mb
    (file.byte_size / (1024 * 1024)).to_f.round(2) if file.attached?
  end

  private
    def file_type_and_size
      return unless file.attached?

      allowed_types = ["application/pdf", "application/msword", 
                       "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
      
      errors.add(:file, "must be a PDF or Word document") unless allowed_types.include?(file.content_type)
      errors.add(:file, "must be less than 10MB") if file.byte_size > 10.megabytes
    end

    def analyze_document
      return unless file.attached?
      
      puts "Document #{title} uploaded"
      puts "- Type: #{file.content_type}"
      puts "- Size: #{file_size_mb} MB"
      puts "- Analyzed: #{file.analyzed?}"
    end
end
```

```ruby
# app/controllers/documents_controller.rb
class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :download]

  def create
    @document = current_user.documents.build(document_params)
    
    if @document.save
      redirect_to @document, notice: "Document uploaded"
    else
      render :new
    end
  end

  def download
    send_data @document.file.download,
              filename: @document.file.filename.to_s,
              type: @document.file.content_type,
              disposition: "attachment"
  end

  private
    def document_params
      params.require(:document).permit(:title, :file)
    end

    def set_document
      @document = Document.find(params[:id])
    end
end
```

```erb
<!-- app/views/documents/show.html.erb -->
<div class="document-detail">
  <h1><%= @document.title %></h1>

  <% if @document.file.attached? %>
    <div class="document-info">
      <p>Type: <%= @document.file_type %></p>
      <p>Size: <%= @document.file_size_mb %> MB</p>
      <p>Uploaded: <%= @document.created_at.strftime("%B %d, %Y") %></p>
    </div>

    <div class="document-actions">
      <%= link_to "Download", download_document_path(@document), 
                   class: "btn btn-primary" %>
      <%= link_to "Delete", @document, method: :delete, 
                   data: { confirm: "Are you sure?" }, class: "btn btn-danger" %>
    </div>
  <% end %>
</div>
```

## Example 4: Direct Upload with Progress

File upload with real-time progress indication.

```erb
<!-- app/views/products/new.html.erb -->
<div id="uploads" class="uploads-container"></div>

<%= form_with model: @product, local: true, id: "product-form" do |form| %>
  <%= form.text_field :name, placeholder: "Product Name" %>
  
  <div class="form-group">
    <label>Product Images (Direct Upload)</label>
    <%= form.file_field :images, multiple: true, 
                         direct_upload: true, accept: "image/*" %>
  </div>

  <%= form.submit "Create Product" %>
<% end %>
```

```javascript
// app/javascript/direct_uploads.js

addEventListener("direct-upload:initialize", event => {
  const { id, file } = event.detail
  
  const div = document.createElement("div")
  div.id = `direct-upload-${id}`
  div.className = "upload-item"
  div.innerHTML = `
    <div class="upload-name">${file.name}</div>
    <div class="progress">
      <div class="progress-bar" style="width: 0%"></div>
    </div>
  `
  
  document.getElementById("uploads").appendChild(div)
})

addEventListener("direct-upload:progress", event => {
  const { id, progress } = event.detail
  const bar = document.querySelector(`#direct-upload-${id} .progress-bar`)
  bar.style.width = `${progress}%`
})

addEventListener("direct-upload:error", event => {
  event.preventDefault()
  const { id, error } = event.detail
  const div = document.getElementById(`direct-upload-${id}`)
  div.className = "upload-item upload-error"
  div.innerHTML += `<p class="error">${error}</p>`
})

addEventListener("direct-upload:end", event => {
  const { id } = event.detail
  const div = document.getElementById(`direct-upload-${id}`)
  div.classList.add("upload-complete")
})
```

```css
/* app/assets/stylesheets/direct_uploads.css */

.uploads-container {
  margin: 1rem 0;
}

.upload-item {
  padding: 1rem;
  margin: 0.5rem 0;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: #f9f9f9;
}

.upload-name {
  font-weight: bold;
  margin-bottom: 0.5rem;
}

.progress {
  height: 20px;
  background: #e9e9e9;
  border-radius: 3px;
  overflow: hidden;
}

.progress-bar {
  height: 100%;
  background: #4CAF50;
  transition: width 200ms ease;
}

.upload-error {
  border-color: #f44336;
  background: #ffebee;
}

.upload-error .error {
  color: #c62828;
  margin-top: 0.5rem;
}

.upload-complete {
  border-color: #4CAF50;
  background: #f1f8f6;
}
```

## Example 5: Querying and Filtering

Find attachments by type and size.

```ruby
# app/models/media_library.rb
class MediaLibrary
  # Find all large images
  def self.large_images
    ActiveRecord::Base.connection.execute(<<-SQL
      SELECT * FROM active_storage_blobs
      WHERE content_type LIKE 'image/%'
      AND byte_size > 1000000
    SQL
    )
  end

  # Find images uploaded in last 7 days
  def self.recent_images
    Post.joins(:images_blobs)
        .where(active_storage_blobs: { content_type: "image/jpeg" })
        .where("active_storage_blobs.created_at > ?", 7.days.ago)
        .distinct
  end

  # Get storage statistics
  def self.storage_stats
    {
      total_blobs: ActiveStorage::Blob.count,
      total_size_mb: (ActiveStorage::Blob.sum(:byte_size) / (1024 * 1024)).to_f.round(2),
      images: ActiveStorage::Blob.where("content_type LIKE ?", "image/%").count,
      documents: ActiveStorage::Blob.where("content_type LIKE ?", "application/%").count,
      unattached: ActiveStorage::Blob.unattached.count
    }
  end
end
```

Usage:

```ruby
# In controller or view
@stats = MediaLibrary.storage_stats
@recent = MediaLibrary.recent_images
```
