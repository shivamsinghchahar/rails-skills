# Direct Uploads

This guide covers client-side file uploads that bypass your Rails server and upload directly to cloud storage (S3, GCS, etc.).

## Why Direct Uploads?

- **Reduced server load**: Files bypass your application servers
- **Better UX**: Faster uploads and progress indication
- **Form validation resilience**: Uploads persist even if form validation fails
- **Cost savings**: Avoid transferring large files through your infrastructure

## Setup

### 1. Include Active Storage JavaScript

Add to your application layout:

```erb
<head>
  <%= javascript_include_tag "activestorage" %>
</head>
```

Or via importmap:

```ruby
# config/importmap.rb
pin "@rails/activestorage", to: "activestorage.esm.js"
```

```erb
<script type="module-shim">
  import * as ActiveStorage from "@rails/activestorage"
  ActiveStorage.start()
</script>
```

### 2. Configure File Field

```erb
<%= form.file_field :avatar, direct_upload: true %>

<%= form.file_field :images, multiple: true, direct_upload: true %>
```

Without form builder:

```html
<input type="file" data-direct-upload-url="<%= rails_direct_uploads_url %>" />
```

### 3. Configure CORS

Allow your domain to upload to cloud storage.

#### S3 CORS Configuration

In AWS Console, set bucket CORS:

```json
[
  {
    "AllowedHeaders": [
      "Content-Type",
      "Content-MD5",
      "Content-Disposition"
    ],
    "AllowedMethods": ["PUT"],
    "AllowedOrigins": ["https://www.example.com"],
    "MaxAgeSeconds": 3600
  }
]
```

Or via AWS CLI:

```bash
aws s3api put-bucket-cors --bucket my-bucket --cors-configuration file://cors.json
```

#### Google Cloud Storage CORS Configuration

```bash
gsutil cors set cors.json gs://my-bucket
```

Where `cors.json`:

```json
[
  {
    "origin": ["https://www.example.com"],
    "method": ["PUT"],
    "responseHeader": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "maxAgeSeconds": 3600
  }
]
```

## JavaScript Events

Monitor upload progress with custom JavaScript events:

```javascript
addEventListener("direct-uploads:start", event => {
  console.log("Direct uploads starting")
})

addEventListener("direct-upload:initialize", event => {
  const { id, file } = event.detail
  console.log(`Upload ${id} initialized: ${file.name}`)
})

addEventListener("direct-upload:start", event => {
  const { id, file } = event.detail
  console.log(`Upload ${id} started: ${file.name}`)
})

addEventListener("direct-upload:progress", event => {
  const { id, progress } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.style.width = `${progress}%`
})

addEventListener("direct-upload:error", event => {
  event.preventDefault()
  const { id, error } = event.detail
  console.error(`Upload ${id} error: ${error}`)
})

addEventListener("direct-upload:end", event => {
  const { id } = event.detail
  console.log(`Upload ${id} ended`)
})

addEventListener("direct-uploads:end", event => {
  console.log("All direct uploads completed")
})
```

## Progress Bar Example

### HTML

```erb
<div id="uploads" class="uploads"></div>

<%= form_with model: @product, local: true do |form| %>
  <%= form.file_field :images, multiple: true, direct_upload: true, id: "gallery-images" %>
  <%= form.submit "Upload" %>
<% end %>
```

### JavaScript

```javascript
// app/javascript/direct_uploads.js

addEventListener("direct-upload:initialize", event => {
  const { target, detail } = event
  const { id, file } = detail

  const div = document.createElement("div")
  div.id = `direct-upload-${id}`
  div.classList.add("direct-upload", "direct-upload--pending")
  
  div.innerHTML = `
    <div class="direct-upload__progress" style="width: 0%"></div>
    <span class="direct-upload__filename">${file.name}</span>
  `

  document.getElementById("uploads").appendChild(div)
})

addEventListener("direct-upload:start", event => {
  const { id } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.classList.remove("direct-upload--pending")
})

addEventListener("direct-upload:progress", event => {
  const { id, progress } = event.detail
  const progressElement = document.getElementById(`direct-upload-${id}`)
                                   .querySelector(".direct-upload__progress")
  progressElement.style.width = `${progress}%`
})

addEventListener("direct-upload:error", event => {
  event.preventDefault()
  const { id, error } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.classList.add("direct-upload--error")
  element.setAttribute("title", error)
})

addEventListener("direct-upload:end", event => {
  const { id } = event.detail
  const element = document.getElementById(`direct-upload-${id}`)
  element.classList.add("direct-upload--complete")
})
```

### CSS

```css
.direct-upload {
  display: inline-block;
  position: relative;
  padding: 2px 4px;
  margin: 0 3px 3px 0;
  border: 1px solid #ccc;
  border-radius: 3px;
  font-size: 11px;
}

.direct-upload--pending {
  opacity: 0.6;
}

.direct-upload__progress {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  opacity: 0.2;
  background: #0076ff;
  transition: width 120ms ease-out;
}

.direct-upload--complete .direct-upload__progress {
  opacity: 0.4;
}

.direct-upload--error {
  border-color: #cc0000;
}

.direct-upload__filename {
  position: relative;
  z-index: 1;
}
```

## DirectUpload JavaScript Class

For custom implementations:

```javascript
import { DirectUpload } from "@rails/activestorage"

const input = document.querySelector('input[type=file]')
const url = input.dataset.directUploadUrl

const onDrop = (event) => {
  event.preventDefault()
  Array.from(event.dataTransfer.files).forEach(file => uploadFile(file))
}

const uploadFile = (file) => {
  const upload = new DirectUpload(file, url)

  upload.create((error, blob) => {
    if (error) {
      console.error("Upload error:", error)
    } else {
      // Create hidden input with blob signed_id
      const hiddenInput = document.createElement('input')
      hiddenInput.type = 'hidden'
      hiddenInput.name = input.name
      hiddenInput.value = blob.signed_id
      document.querySelector('form').appendChild(hiddenInput)
    }
  })
}

input.addEventListener('change', (event) => {
  Array.from(input.files).forEach(file => uploadFile(file))
})
```

## With Progress Tracking

Track progress with a custom delegate:

```javascript
class Uploader {
  constructor(file, url) {
    this.upload = new DirectUpload(file, url, this)
  }

  uploadFile() {
    this.upload.create((error, blob) => {
      if (error) {
        console.error("Upload error:", error)
      } else {
        const hiddenInput = document.createElement('input')
        hiddenInput.type = 'hidden'
        hiddenInput.name = 'gallery[]'
        hiddenInput.value = blob.signed_id
        document.querySelector('form').appendChild(hiddenInput)
      }
    })
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", event => {
      const progress = (event.loaded / event.total) * 100
      this.updateProgressBar(progress)
    })
  }

  updateProgressBar(percent) {
    // Update UI with progress
    console.log(`Upload progress: ${percent}%`)
  }
}

document.addEventListener('change', (event) => {
  if (event.target.matches('input[type=file][direct-upload-url]')) {
    Array.from(event.target.files).forEach(file => {
      new Uploader(file, event.target.dataset.directUploadUrl).uploadFile()
    })
  }
})
```

## Form Validation

### Retain Uploads on Validation Failure

Hidden fields preserve uploads if form validation fails:

```erb
<%= form_with model: @product, local: true do |form| %>
  <% if @product.errors.any? %>
    <div class="error">
      <%= pluralize(@product.errors.count, "error") %> prohibited:
      <ul>
        <% @product.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <%= form.text_field :name %>
  <%= form.text_area :description %>

  <!-- Retain existing attachments -->
  <% @product.images.each do |image| %>
    <%= form.hidden_field :images, multiple: true, value: image.signed_id %>
  <% end %>

  <!-- Allow adding new images -->
  <%= form.file_field :images, multiple: true, direct_upload: true %>

  <%= form.submit "Save Product" %>
<% end %>
```

## Server-Side Handler

Create a custom DirectUploadsController for authentication:

```ruby
# app/controllers/direct_uploads_controller.rb
class DirectUploadsController < ActiveStorage::DirectUploadsController
  skip_forgery_protection
  before_action :authenticate_user!

  def create
    # Add custom authorization logic
    if current_user.can_upload?
      super
    else
      head :unauthorized
    end
  end
end
```

And in routes:

```ruby
# config/routes.rb
post "/rails/active_storage/direct_uploads", to: "direct_uploads#create"
```

## Unattached Uploads Cleanup

Direct uploads are stored even if form submission fails or is abandoned. Clean them up:

```ruby
# lib/tasks/active_storage.rake
namespace :active_storage do
  desc "Purge unattached blobs older than 2 days"
  task purge_unattached: :environment do
    ActiveStorage::Blob.unattached.where("created_at <= ?", 2.days.ago).find_each(&:purge_later)
  end
end
```

Run as cron job:

```ruby
# config/recurring.yml
purge_unattached_uploads:
  command: 'rake active_storage:purge_unattached'
  schedule: 'every day at 02:00'
```

## Best Practices

1. **Validate on Client**: Check file size and type before uploading
2. **Validate on Server**: Always re-validate uploaded files
3. **Handle Errors**: Provide clear error messages to users
4. **CORS Carefully**: Allow only your domain
5. **Cleanup Scheduled**: Purge unattached files regularly
6. **Track Progress**: Show progress to improve UX
7. **Test Thoroughly**: Test with various file sizes and types
