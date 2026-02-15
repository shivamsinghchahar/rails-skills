# Sessions, Cookies, and Flash Messages

Managing session state, persistent data, and temporary notifications across requests.

## Sessions

Sessions store user data across multiple requests. By default, Rails stores session data in cookies.

```ruby
class UsersController < ApplicationController
  def login
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path
    else
      render :login
    end
  end

  def dashboard
    @user = User.find(session[:user_id])
  end

  def logout
    session[:user_id] = nil
    redirect_to login_path
  end
end
```

### Session Configuration

Configure sessions in `config/initializers/session_store.rb` or `config/application.rb`:

```ruby
Rails.application.config.session_store :cookie_store,
  key: '_app_session',
  secure: true,
  http_only: true,
  same_site: :strict
```

### Session Storage Options

- `:cookie_store` - Default, stores encrypted data in cookies
- `:active_record_store` - Database storage (requires sessions table)
- `:mem_cache_store` - Memcached storage
- `:redis_store` - Redis storage (via gem)

## Cookies

Cookies persist data in the browser. Rails provides helper methods for cookie management.

```ruby
class PreferencesController < ApplicationController
  def set_theme
    cookies[:theme] = { 
      value: params[:theme],
      expires: 30.days.from_now,
      secure: true,
      http_only: true
    }
    redirect_to root_path
  end

  def get_theme
    cookies[:theme] || 'light'
  end
end
```

### Signed Cookies

Prevent tampering by verifying cookie integrity:

```ruby
cookies.signed[:user_id] = current_user.id
current_user.id == cookies.signed[:user_id]  # true
```

Rails automatically verifies the signature before reading.

### Encrypted Cookies

Store sensitive data securely:

```ruby
cookies.encrypted[:credit_card] = '4111-1111-1111-1111'
# Cookie is encrypted with Rails' secret_key_base
cookies.encrypted[:credit_card]  # decrypted value
```

### Permanent Cookies

Cookies expire in 20 years by default:

```ruby
cookies.permanent[:remember_me] = current_user.id
# Also works with signed/encrypted
cookies.permanent.signed[:auth_token] = generate_token
```

## Flash Messages

Display one-time messages that persist across a redirect.

```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)
    if @post.save
      flash[:success] = "Post created!"
      redirect_to @post
    else
      flash[:error] = @post.errors.full_messages.join(", ")
      render :new
    end
  end
end
```

### Flash Types

```ruby
flash[:notice]   # Generic message
flash[:alert]    # Warning/error message
flash[:success]  # Success confirmation
flash[:error]    # Error message
flash[:warning]  # Warning message

# Custom types
flash[:custom_message] = "Your custom message"
```

### Display in Views

```erb
<% if flash[:success] %>
  <div class="alert alert-success">
    <%= flash[:success] %>
  </div>
<% end %>

<% if flash[:error] %>
  <div class="alert alert-danger">
    <%= flash[:error] %>
  </div>
<% end %>
```

### Flash.now for Same-Request Display

Use `flash.now` when rendering without redirect:

```ruby
def create
  @post = Post.new(post_params)
  if @post.save
    flash[:success] = "Post created!"
    redirect_to @post
  else
    flash.now[:error] = @post.errors.full_messages.join(", ")
    render :new  # Same request, use flash.now
  end
end
```

## Session Security Best Practices

1. **CSRF Protection**: Rails includes CSRF tokens by default in forms
2. **Secure Flag**: Set `secure: true` for HTTPS-only cookies
3. **HttpOnly Flag**: Set `http_only: true` to prevent JavaScript access
4. **SameSite**: Set `same_site: :strict` or `:lax` to prevent CSRF
5. **Expiration**: Set appropriate timeouts for sessions
6. **Encryption**: Use encrypted cookies for sensitive data
7. **Signed Cookies**: Use signed cookies to prevent tampering

```ruby
# Secure configuration
Rails.application.config.session_store :cookie_store,
  key: '_secure_session',
  secure: !Rails.env.development?,
  http_only: true,
  same_site: :lax,
  expire_after: 1.week
```

## Common Patterns

### Authentication Token Storage

```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      cookies.signed[:auth_token] = {
        value: user.generate_auth_token,
        expires: 1.month.from_now,
        secure: true,
        http_only: true
      }
      redirect_to dashboard_path
    end
  end
end
```

### User Preferences Storage

```ruby
def set_language
  cookies.permanent[:locale] = params[:locale]
  # Or in session
  session[:locale] = params[:locale]
end

def current_locale
  session[:locale] || cookies[:locale] || I18n.default_locale
end
```

### Flash Message Chaining

```ruby
def create
  if @record.save
    flash[:success] = "Created successfully"
  else
    flash[:error] = @record.errors.full_messages.to_sentence
  end
  redirect_to index_path
end
```

## Clearing Sessions and Cookies

```ruby
def logout
  session.clear                  # Clear entire session
  session.delete(:user_id)       # Delete specific key
  cookies.delete(:remember_me)   # Delete cookie
  cookies.clear                  # Clear all cookies
  redirect_to login_path
end
```
