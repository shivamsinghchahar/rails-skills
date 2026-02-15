# Connection Setup and Authentication

The connection is the foundation of Action Cable. It establishes the WebSocket handshake and authenticates users before allowing channel subscriptions.

## Basic Connection Class

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      if verified_user = User.find_by(id: cookies.encrypted[:user_id])
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

The `identified_by :current_user` declares that the connection is identified by the current user, making it available to all channels created from this connection.

## Authentication Methods

### Method 1: Encrypted Cookies

Use encrypted cookies set after user authentication:

```ruby
# After successful login
cookies.encrypted[:user_id] = current_user.id

# In connection.rb
def find_verified_user
  if user_id = cookies.encrypted[:user_id]
    User.find_by(id: user_id)
  else
    reject_unauthorized_connection
  end
end
```

### Method 2: Session Store

Extract user from Rails session:

```ruby
def find_verified_user
  if session[:user_id]
    User.find_by(id: session[:user_id])
  else
    reject_unauthorized_connection
  end
end

private

def session
  @session ||= cookies.encrypted['_session']
end
```

### Method 3: Query Parameters (Token-Based)

Pass authentication token in WebSocket URL:

```ruby
def find_verified_user
  if token = request.params[:token]
    user = User.find_by(authentication_token: token)
    user if user&.valid_token?
  else
    reject_unauthorized_connection
  end
end
```

On the client:

```javascript
const token = localStorage.getItem('auth-token')
const consumer = createConsumer(`wss://example.com/cable?token=${token}`)
```

### Method 4: Devise Integration

Using Rails' Devise authentication:

```ruby
def find_verified_user
  env['warden'].user || reject_unauthorized_connection
end
```

## Connection Identifiers

Identifiers make it easy to find specific connections later:

```ruby
# Single identifier
identified_by :current_user

# Multiple identifiers
identified_by :current_user, :current_account

def connect
  self.current_user = find_verified_user
  self.current_account = find_current_account
end
```

Access identifiers in channels:

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @user = current_user      # From connection
    @account = current_account # From connection
  end
end
```

## Rejecting Connections

Reject unauthorized WebSocket connections:

```ruby
def connect
  self.current_user = find_verified_user
  reject_unauthorized_connection unless current_user
end

# Or immediately reject
def connect
  if request.env['HTTP_ORIGIN'] != allowed_origin
    reject_unauthorized_connection
  end
end
```

## Exception Handling

Globally handle connection errors:

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    rescue_from StandardError, with: :report_error

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      User.find(cookies.encrypted[:user_id])
    rescue => e
      report_error(e)
      reject_unauthorized_connection
    end

    def report_error(error)
      Rails.logger.error("Cable connection error: #{error.message}")
      SomeExternalBugtrackingService.notify(error)
    end
  end
end
```

## Connection Callbacks

Execute code at key points in the connection lifecycle:

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    before_command :set_locale
    after_command :log_activity
    around_command :track_time

    private

    def set_locale
      I18n.locale = current_user.locale
    end

    def log_activity
      Rails.logger.info("User #{current_user.id} activity")
    end

    def track_time
      start = Time.current
      yield
      duration = Time.current - start
      Rails.logger.info("Command took #{duration}s")
    end
  end
end
```

## Managing Connections

Find all connections for a user:

```ruby
# Find all open WebSocket connections for a user
connections = ActionCable.server.remote_connections.where(current_user: current_user)

# Force disconnect all connections for a user
connections.disconnect(reconnect: true)
```

Useful for:
- Logging out users everywhere
- Forcing reconnection after permission changes
- Graceful shutdown
- Disabling user accounts

## Testing Connections

```ruby
require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid cookie" do
    cookies.encrypted[:user_id] = users(:john).id
    connect
    assert_equal connection.current_user, users(:john)
  end

  test "rejects connection without valid user" do
    assert_reject_connection { connect }
  end

  test "connects with query parameters" do
    connect params: { token: 'valid-token' }
    assert_equal connection.current_user, users(:john)
  end
end
```

## Security Considerations

1. **Always authenticate** — Never skip `find_verified_user`
2. **Use secure cookies** — Use `cookies.encrypted` not plain cookies
3. **Validate origins** — Check `request.origin` against whitelist
4. **Rate limit** — Prevent connection spam with rate limiting
5. **Timeout idle** — Disconnect inactive WebSocket connections
6. **Validate params** — Sanitize and validate all incoming parameters
7. **Log failures** — Monitor authentication failures for suspicious activity
8. **HTTPS only** — Always use `wss://` in production

## Common Patterns

### Keep User Online Indicator

Track when users are online:

```ruby
def connect
  self.current_user = find_verified_user
  current_user.update(online: true, last_seen_at: Time.current)
end

def disconnect
  current_user.update(online: false)
end
```

### Broadcast Connection Event

Notify others when user connects/disconnects:

```ruby
def connect
  self.current_user = find_verified_user
  NotificationChannel.broadcast_to(
    current_user.account,
    { type: 'user_online', user: current_user }
  )
end
```

### Rate Limiting

Prevent connection spam:

```ruby
def connect
  self.current_user = find_verified_user
  
  if too_many_connections?
    reject_unauthorized_connection
  end
end

private

def too_many_connections?
  max_connections = 5
  existing = ActionCable.server.remote_connections
    .where(current_user: current_user).count
  existing >= max_connections
end
```
