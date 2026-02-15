# Streaming and File Responses

Handling file downloads, uploads, and streaming responses in Rails controllers.

## Sending Files

### send_file

Send files to the client:

```ruby
class FilesController < ApplicationController
  def download
    file_path = Rails.root.join('public', 'documents', 'report.pdf')
    send_file(file_path)
  end
end
```

With options:

```ruby
send_file(file_path,
  filename: "custom_name.pdf",
  type: "application/pdf",
  disposition: :attachment  # Force download instead of inline display
)
```

Disposition options:
- `:attachment` - Download the file
- `:inline` - Display in browser (default)

### send_data

Send generated data without saving to disk:

```ruby
class ReportsController < ApplicationController
  def export_csv
    csv_data = generate_csv_report
    send_data(csv_data,
      filename: "report_#{Date.today}.csv",
      type: "text/csv",
      disposition: :attachment
    )
  end

  private

  def generate_csv_report
    CSV.generate do |csv|
      csv << ["Name", "Email", "Created"]
      User.find_each do |user|
        csv << [user.name, user.email, user.created_at]
      end
    end
  end
end
```

### Streaming Large Files

For large files, stream directly to avoid memory issues:

```ruby
class BackupsController < ApplicationController
  def download_backup
    file_path = Rails.root.join('backups', 'db.tar.gz')
    
    send_file(file_path,
      filename: "backup.tar.gz",
      type: "application/gzip",
      disposition: :attachment,
      stream: true,
      buffer_size: 4096
    )
  end
end
```

## Streaming Responses

### Stream with send_stream

Modern way to stream response bodies:

```ruby
class EventsController < ApplicationController
  def stream_events
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'
    
    response.stream.write "data: Event 1\n\n"
    response.stream.write "data: Event 2\n\n"
    response.stream.close
  end
end
```

### Server-Sent Events (SSE)

```ruby
class NotificationsController < ApplicationController
  def stream
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    
    response.stream.write("data: #{Time.current}\n\n")
    
    5.times do |i|
      sleep(1)
      response.stream.write("data: Message #{i}\n\n")
    end
    
    response.stream.close
  rescue IOError
    # Client closed connection
  end
end
```

### Real-time Updates with ActionCable

```ruby
# In WebSocket controller
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room_id]}"
  end

  def send_message(data)
    message = ChatMessage.create(
      user: current_user,
      content: data['message'],
      room_id: params[:room_id]
    )
    
    ActionCable.server.broadcast(
      "chat_#{params[:room_id]}",
      message: message
    )
  end
end
```

## Handling File Uploads

### Basic File Upload

```ruby
class DocumentsController < ApplicationController
  def create
    document = Document.new(document_params)
    if document.save
      redirect_to document_path(document), notice: 'Uploaded'
    else
      render :new
    end
  end

  private

  def document_params
    params.require(:document).permit(:file)
  end
end

# Model with Active Storage
class Document < ApplicationRecord
  has_one_attached :file
end
```

### Multiple File Uploads

```ruby
class GalleriesController < ApplicationController
  def create
    gallery = Gallery.new(gallery_params)
    
    if params[:images].present?
      params[:images].each do |image|
        gallery.images.attach(image)
      end
    end
    
    if gallery.save
      redirect_to gallery_path(gallery)
    else
      render :new
    end
  end

  private

  def gallery_params
    params.require(:gallery).permit(:title, :description)
  end
end
```

### File Validation

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  validates :file, presence: true,
    attached: true,
    size: { less_than: 10.megabytes },
    content_type: { in: %w[application/pdf text/csv] }
end
```

With custom validation:

```ruby
class Document < ApplicationRecord
  has_one_attached :file
  
  validate :file_size_limit
  
  private
  
  def file_size_limit
    if file.attached? && file.byte_size > 10.megabytes
      errors.add(:file, "File size cannot exceed 10MB")
    end
  end
end
```

## Serving Files

### Private File Access Control

```ruby
class FilesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_file_access, only: [:show]

  def show
    @file = Document.find(params[:id])
    send_file @file.file.blob.service.path_for(@file.file.key),
      filename: @file.file.filename,
      type: @file.file.content_type,
      disposition: :attachment
  end

  private

  def authorize_file_access
    @file = Document.find(params[:id])
    render :unauthorized unless @file.accessible_by?(current_user)
  end
end
```

### Temporary URLs for Cloud Storage

```ruby
class ImagesController < ApplicationController
  def download
    image = Image.find(params[:id])
    
    # Generate signed URL for S3/GCS
    url = image.image.blob.service_url(expires_in: 1.hour)
    
    redirect_to url
  end
end
```

## Response Headers and Content Types

```ruby
class ExportsController < ApplicationController
  def export_json
    data = generate_json_export
    render json: data,
      status: :ok,
      content_type: 'application/json; charset=utf-8'
  end

  def export_xml
    data = generate_xml_export
    render xml: data,
      status: :ok,
      content_type: 'application/xml; charset=utf-8'
    
    response.headers['Content-Disposition'] = 'attachment; filename=export.xml'
  end

  def export_pdf
    pdf = generate_pdf_report
    send_data pdf.render,
      filename: "report.pdf",
      type: "application/pdf",
      disposition: :attachment
  end

  private

  def generate_json_export
    User.all.as_json(only: [:id, :email, :name])
  end

  def generate_xml_export
    # Use a gem like builder or similar
  end

  def generate_pdf_report
    # Use a gem like Prawn or similar
  end
end
```

## Compression and Performance

### Gzip Compression

Rails automatically handles gzip compression via middleware:

```ruby
# config/middleware.rb
use Rack::Deflater
```

### Streaming with Enumerator

```ruby
class DataController < ApplicationController
  def stream_data
    data_enumerator = Enumerator.new do |yielder|
      100.times do |i|
        yielder << "#{i},#{Time.current}\n"
      end
    end
    
    send_data data_enumerator,
      filename: "data.csv",
      type: "text/csv",
      disposition: :attachment
  end
end
```

## Error Handling in File Operations

```ruby
class DownloadsController < ApplicationController
  def download
    file_path = Rails.root.join('files', params[:filename])
    
    # Security: prevent directory traversal
    unless file_path.expand_path.start_with?(Rails.root.join('files').expand_path)
      render :not_found
      return
    end
    
    unless File.exist?(file_path)
      render :not_found
      return
    end
    
    send_file file_path,
      filename: File.basename(file_path),
      type: File.mime_type?(File.extname(file_path))
  rescue => e
    Rails.logger.error("Download error: #{e.message}")
    render :error, status: :internal_server_error
  end
end
```
