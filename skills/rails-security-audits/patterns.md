# Security Patterns and Common Vulnerabilities

## Input Validation

```ruby
# Bad: Trust user input
def search
  @results = Product.where("name LIKE '#{params[:q]}'")
end

# Good: Use parameterized queries
def search
  @results = Product.where("name ILIKE ?", "%#{params[:q]}%")
end

# Better: Use scopes
def search
  @results = Product.search(params[:q])
end

# Model
class Product < ApplicationRecord
  scope :search, ->(query) { where("name ILIKE ?", "%#{query}%") }
  validates :name, presence: true, length: { minimum: 1 }
end
```

## Authentication & Authorization

```ruby
# Bad: Missing authentication
class AdminController < ApplicationController
  def users
    @users = User.all
  end
end

# Good: Add authentication
class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  
  def users
    @users = User.all
  end
  
  private
  
  def authorize_admin!
    redirect_to root_path unless current_user.admin?
  end
end
```

## Password Security

```ruby
# Bad: Storing plain passwords
class User
  def authenticate(password)
    self.password == password
  end
end

# Good: Use bcrypt
class User < ApplicationRecord
  has_secure_password
  validates :password, length: { minimum: 8 }
end

# Usage
user = User.create(email: 'user@example.com', password: 'securepass123')
user.authenticate('securepass123')  # Returns user if correct
```

## CSRF Protection

```erb
<!-- Good: Automatic in Rails -->
<%= form_with(local: true) do |form| %>
  <!-- Rails automatically includes CSRF token -->
  <%= form.submit %>
<% end %>

<!-- Or explicit -->
<form method="POST" action="/posts">
  <%= hidden_field_tag :authenticity_token, form_authenticity_token %>
</form>
```

## File Upload Security

```ruby
# Bad: Accept any file type
def upload
  @file = params[:file]
  File.write("public/uploads/#{@file.original_filename}", @file.read)
end

# Good: Validate file type and size
def upload
  validate_file(params[:file])
  @file = params[:file]
  filename = SecureRandom.hex + File.extname(@file.original_filename)
  File.write("public/uploads/#{filename}", @file.read)
end

private

def validate_file(file)
  allowed_types = ['image/jpeg', 'image/png', 'application/pdf']
  max_size = 10.megabytes
  
  raise 'Invalid file type' unless allowed_types.include?(file.content_type)
  raise 'File too large' unless file.size <= max_size
end
```

## SQL Injection Prevention

```ruby
# Bad
User.where("email = '#{params[:email]}'")

# Good: Use placeholders
User.where("email = ?", params[:email])

# Good: Use where with hash
User.where(email: params[:email])

# Good: Use find_by
User.find_by(email: params[:email])

# Good: Use safe comparison
User.find_by(email: params[:email].downcase.strip)
```

## XSS Prevention

```erb
<!-- Bad: Unescaped HTML -->
<%= @comment.text %>

<!-- Good: Escaped (Rails default) -->
<%= h @comment.text %>

<!-- Good: For safe HTML, use sanitize -->
<%= sanitize @comment.text %>

<!-- Use CSP to prevent inline scripts -->
```

## Environment Variables

```ruby
# Bad: Hardcoded secrets
API_KEY = 'sk_live_123456'

# Good: Use environment variables
API_KEY = ENV['STRIPE_API_KEY']

# Better: Use encrypted credentials
Rails.application.credentials.stripe_api_key

# config/credentials.yml.enc
stripe_api_key: sk_live_123456
```

## Error Handling

```ruby
# Bad: Expose internal details
def show
  @user = User.find(params[:id])
rescue => e
  render text: e.message
end

# Good: Generic error message
def show
  @user = User.find(params[:id])
rescue ActiveRecord::RecordNotFound
  render text: 'Not found', status: :not_found
end

# Good: Log errors securely
def show
  @user = User.find(params[:id])
rescue => error
  Rails.logger.error("Error: #{error.message}")
  Sentry.capture_exception(error)
  render text: 'Something went wrong', status: :internal_server_error
end
```
