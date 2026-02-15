# Advanced Authentication & Error Handling

Implementing authentication strategies and handling exceptions in controllers.

## HTTP Authentication

Rails provides built-in HTTP authentication methods for API endpoints.

### Basic Authentication

```ruby
class ApiController < ApplicationController
  http_basic_authenticate_with name: "username", password: "password"
  
  def protected_action
    render json: { message: "Authenticated" }
  end
end
```

For multiple credentials:

```ruby
class ApiController < ApplicationController
  before_action :authenticate_api_user

  private

  def authenticate_api_user
    authenticate_or_request_with_http_basic do |username, password|
      username == ENV['API_USERNAME'] && password == ENV['API_PASSWORD']
    end
  end
end
```

### Digest Authentication

More secure than basic auth, uses MD5 hashing:

```ruby
class ApiController < ApplicationController
  http_digest_authenticate_with name: "username", password: "password"
end
```

For dynamic credentials:

```ruby
class ApiController < ApplicationController
  before_action :authenticate_with_digest

  private

  def authenticate_with_digest
    authenticate_or_request_with_http_digest("My Realm") do |username|
      User.find_by(username: username)&.password_digest
    end
  end
end
```

### Token Authentication

```ruby
class ApiController < ApplicationController
  before_action :authenticate_token

  private

  def authenticate_token
    authenticate_or_request_with_http_token do |token, options|
      User.find_by(api_token: token)
    end
  end
end
```

Usage with Authorization header:

```ruby
# Client request
curl -H "Authorization: Token token=YOUR_TOKEN" https://api.example.com/data

# Server
class ApiController < ApplicationController
  before_action :verify_token

  private

  def verify_token
    @user = User.find_by(api_token: token_from_header)
    render json: { error: "Unauthorized" }, status: :unauthorized unless @user
  end

  def token_from_header
    request.headers.fetch("Authorization", "").sub(/^Token\s+/, "")
  end
end
```

## Bearer Token Authentication

Modern pattern for API authentication:

```ruby
class ApiController < ApplicationController
  before_action :verify_bearer_token

  private

  def verify_bearer_token
    bearer_token = request.headers.fetch("Authorization", "").sub(/^Bearer\s+/, "")
    @user = User.find_by(auth_token: bearer_token)
    
    render json: { error: "Unauthorized" }, status: :unauthorized unless @user
  end
end
```

## Exception Handling with rescue_from

Handle exceptions globally in controllers:

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from StandardError, with: :generic_error

  private

  def record_not_found
    render json: { error: "Resource not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: { 
      error: "Validation failed",
      details: exception.record.errors
    }, status: :unprocessable_entity
  end

  def generic_error(exception)
    Rails.logger.error(exception)
    render json: { error: "Internal server error" }, status: :internal_server_error
  end
end
```

### Custom Exceptions

```ruby
class ApiError < StandardError; end
class AuthenticationError < ApiError; end
class AuthorizationError < ApiError; end

class ApiController < ApplicationController
  rescue_from AuthenticationError, with: :unauthorized
  rescue_from AuthorizationError, with: :forbidden

  def create
    raise AuthenticationError, "Invalid credentials" unless authenticated?
    raise AuthorizationError, "Not permitted" unless authorized?
    # ... action code
  end

  private

  def unauthorized
    render json: { error: "Authentication required" }, status: :unauthorized
  end

  def forbidden
    render json: { error: "Not authorized" }, status: :forbidden
  end
end
```

## Token Generation and Validation

### Generate Secure Tokens

```ruby
class User < ApplicationRecord
  has_secure_password
  has_secure_token :api_token
  has_secure_token :remember_token
end

# Automatic token generation on user creation
user = User.create(email: "user@example.com", password: "secret")
user.api_token  # => generated secure token

# Regenerate token
user.regenerate_api_token
```

### JWT (JSON Web Tokens)

```ruby
# Gemfile
gem 'jwt'

class AuthController < ApplicationController
  def login
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      token = generate_jwt(user)
      render json: { token: token }, status: :ok
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end

  private

  def generate_jwt(user)
    JWT.encode(
      { user_id: user.id, exp: 24.hours.from_now.to_i },
      Rails.application.secrets.secret_key_base
    )
  end

  def verify_jwt
    token = request.headers["Authorization"]&.sub(/^Bearer\s+/, "")
    payload = JWT.decode(token, Rails.application.secrets.secret_key_base)[0]
    @user = User.find(payload["user_id"])
  rescue JWT::DecodeError
    render json: { error: "Invalid token" }, status: :unauthorized
  end
end
```

## OAuth 2.0 Integration

```ruby
# Gemfile
gem 'omniauth-google-oauth2'
gem 'omniauth-github'

class AuthController < ApplicationController
  def callback
    user = User.from_omniauth(auth_hash)
    session[:user_id] = user.id
    redirect_to dashboard_path
  end

  private

  def auth_hash
    request.env["omniauth.auth"]
  end
end

# In routes.rb
get '/auth/:provider/callback', to: 'auth#callback'

# In User model
class User < ApplicationRecord
  def self.from_omniauth(auth_hash)
    find_or_create_by(provider: auth_hash[:provider], uid: auth_hash[:uid]) do |user|
      user.email = auth_hash[:info][:email]
      user.name = auth_hash[:info][:name]
    end
  end
end
```

## Error Response Patterns

### API Error Response Format

```ruby
class ApiController < ApplicationController
  rescue_from StandardError, with: :error_response

  private

  def error_response(exception)
    status = status_code(exception)
    render json: {
      error: {
        type: exception.class.name,
        message: exception.message,
        timestamp: Time.current
      }
    }, status: status
  end

  def status_code(exception)
    case exception
    when ActiveRecord::RecordNotFound then :not_found
    when ActiveRecord::RecordInvalid then :unprocessable_entity
    when ActiveRecord::Rollback then :bad_request
    else :internal_server_error
    end
  end
end
```

### Render Error with Details

```ruby
def create
  @resource = Resource.new(resource_params)
  if @resource.save
    render json: @resource, status: :created
  else
    render json: { 
      errors: @resource.errors.full_messages,
      details: @resource.errors.details
    }, status: :unprocessable_entity
  end
end
```

## Advanced Patterns

### Multi-Factor Authentication

```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      if user.two_factor_enabled?
        session[:user_id_pending] = user.id
        send_two_factor_code(user)
        redirect_to two_factor_verification_path
      else
        session[:user_id] = user.id
        redirect_to dashboard_path
      end
    else
      render :new, alert: "Invalid credentials"
    end
  end
end
```

### Permission-Based Authorization

```ruby
class PostsController < ApplicationController
  before_action :check_permissions, only: [:edit, :update, :destroy]

  private

  def check_permissions
    @post = Post.find(params[:id])
    render :forbidden unless current_user.can_edit?(@post)
  end

  def current_user
    @current_user ||= User.find(session[:user_id])
  end
end
```

### Rate Limiting

```ruby
class ApiController < ApplicationController
  before_action :check_rate_limit

  private

  def check_rate_limit
    rate_limiter = Rack::Attack::Cache.store
    key = "api_requests:#{request.ip}"
    
    if rate_limiter.read(key).to_i > 100
      render json: { error: "Rate limit exceeded" }, status: :too_many_requests
    else
      rate_limiter.write(key, (rate_limiter.read(key).to_i + 1), 3600)
    end
  end
end
```
