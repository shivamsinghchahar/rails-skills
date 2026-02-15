# Mailers, Views, and Layouts

Building email classes, creating templates, configuring layouts, and using view helpers in Action Mailer.

## Generating Mailers

Use the Rails generator to scaffold a mailer:

```bash
# Generate mailer with action
rails generate mailer User welcome_email

# This creates:
# - app/mailers/user_mailer.rb
# - app/views/user_mailer/welcome_email.html.erb
# - app/views/user_mailer/welcome_email.text.erb
# - test/mailers/user_mailer_test.rb
# - test/mailers/previews/user_mailer_preview.rb
```

You can also manually create mailers in `app/mailers/`:

```ruby
class CustomMailer < ApplicationMailer
  default from: "noreply@example.com"
  
  def notify
    mail(to: "user@example.com", subject: "Notification")
  end
end
```

## ApplicationMailer

All mailers inherit from `ApplicationMailer`, which defines common settings:

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "notifications@example.com"
  layout "mailer"
  
  helper :application  # Include ApplicationHelper
  
  # Common methods available in all mailers
  def company_name
    "My Company"
  end
end
```

## Mailer Actions

Mailer actions send specific email types. They must return the result of calling `mail`:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    @confirmation_url = params[:confirmation_url]
    
    mail(
      to: @user.email,
      subject: "Welcome to #{company_name}",
      cc: "admin@example.com",
      bcc: "archive@example.com",
      reply_to: "support@example.com",
      date: Time.current
    )
  end
  
  def password_reset
    @user = params[:user]
    @reset_token = params[:reset_token]
    
    mail(
      to: @user.email,
      subject: "Reset your password"
    )
  end
  
  # Email with dynamic recipients
  def admin_alert
    @alert = params[:alert]
    
    # Using Proc for dynamic recipients
    mail(to: Admin.pluck(:email), subject: "Alert: #{@alert.title}")
  end
end
```

### Parameterized Mailers

Pass data to mailer actions using `with`:

```ruby
# In controller
UserMailer.with(user: @user, token: @token).password_reset.deliver_later

# In mailer
class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @token = params[:token]
    
    mail(to: @user.email, subject: "Reset Your Password")
  end
end
```

### Default Values

Set defaults for all emails in the mailer:

```ruby
class UserMailer < ApplicationMailer
  default from: "notifications@example.com",
          "X-Priority" => "3"  # Custom headers
  
  # Or use Proc for dynamic values
  default from: -> { "notifications@#{current_domain}" }
end
```

## Email Templates

### HTML and Text Templates

Create both formats for best email client support:

```erb
<!-- app/views/user_mailer/welcome_email.html.erb -->
<!DOCTYPE html>
<html>
  <body>
    <h1>Welcome <%= @user.name %></h1>
    <p>
      You have successfully signed up to example.com.
    </p>
    <p>
      To log in, visit: <%= link_to 'Click here', login_url(host: 'example.com') %>
    </p>
  </body>
</html>
```

```text
<!-- app/views/user_mailer/welcome_email.text.erb -->
Welcome <%= @user.name %>
===============================================

You have successfully signed up.

To log in, visit: <%= login_url(host: 'example.com') %>
```

When both exist, Rails automatically creates a `multipart/alternative` email with both versions.

## Generating URLs in Email Templates

Email views don't have HTTP request context, so you must provide the host:

```ruby
# config/application.rb
config.action_mailer.default_url_options = { host: "example.com", protocol: "https" }

# Override per environment
# config/environments/development.rb
config.action_mailer.default_url_options = { host: "localhost:3000" }
```

Always use `*_url` helpers (with host) instead of `*_path` (relative):

```erb
<!-- WRONG: relative URL won't work in emails -->
<%= link_to "Click here", user_path(@user) %>

<!-- RIGHT: full URL -->
<%= link_to "Click here", user_url(@user) %>

<!-- Can override host per link -->
<%= link_to "Click here", user_url(@user, host: "example.com") %>
```

## Adding Images

Configure asset host for images in emails:

```ruby
# config/application.rb
config.action_mailer.asset_host = "https://example.com"

# Or environment-specific
# config/environments/production.rb
config.action_mailer.asset_host = "https://cdn.example.com"
```

Use `image_tag` as normal:

```erb
<%= image_tag 'logo.png', alt: "Logo" %>
<%= image_tag 'banner.jpg', style: "width: 100%;" %>
```

## Custom Mailer Layouts

Use custom layouts for specific mailers:

```ruby
class MarketingMailer < ApplicationMailer
  layout "marketing_mailer"  # Uses app/views/layouts/marketing_mailer.html.erb
  
  def newsletter
    @articles = params[:articles]
    mail(to: params[:email], subject: "Newsletter")
  end
end
```

Override layout for specific actions:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    mail(to: params[:user].email) do |format|
      format.html { render layout: "welcome_layout" }
      format.text { render layout: "text_layout" }
    end
  end
end
```

## Default Mailer Layouts

```erb
<!-- app/views/layouts/mailer.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <style>
      /* Email CSS needs to be inline or in style tags */
      body { font-family: sans-serif; }
      a { color: #0077cc; }
    </style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

```text
<!-- app/views/layouts/mailer.text.erb -->
<%= yield %>
```

## Custom View Paths

Override where mailers look for templates:

```ruby
class UserMailer < ApplicationMailer
  prepend_view_path "custom/mailer/views"  # Search here first
  
  def welcome_email
    # Looks for: custom/mailer/views/welcome_email
    mail(to: params[:user].email, subject: "Welcome")
  end
end
```

Or specify template path/name per action:

```ruby
def welcome_email
  mail(
    to: params[:user].email,
    subject: "Welcome",
    template_path: "notifications",
    template_name: "hello"
  )
end
```

Or render inline templates:

```ruby
def welcome_email
  @user = params[:user]
  
  mail(to: @user.email, subject: "Welcome") do |format|
    format.html { render plain: "<h1>Welcome</h1>" }
    format.text { render plain: "Welcome" }
  end
end
```

## Email Helpers and Partials

Access view helpers in email templates:

```erb
<!-- app/views/user_mailer/invoice.html.erb -->
<h1>Invoice #<%= @invoice.number %></h1>

<!-- Include a partial -->
<%= render 'shared/invoice_items', invoice: @invoice %>

<!-- Use URL helpers -->
<%= link_to 'View on website', invoice_url(@invoice) %>

<!-- Use formatting helpers -->
<%= number_to_currency(@invoice.total) %>
<%= l(@invoice.created_at, format: :long) %>
```

Access custom helpers from ApplicationHelper:

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def company_name
    "My Company"
  end
  
  def support_email
    "support@example.com"
  end
end

# Use in mailers
module ActionMailer
  class MailHelper
    include ApplicationHelper  # Helpers are available
  end
end
```

## View Caching

Cache fragments in mailer views:

```ruby
# config/environments/production.rb
config.action_mailer.perform_caching = true
```

```erb
<!-- Cache email fragment -->
<% cache do %>
  <%= render 'expensive_partial' %>
<% end %>

<!-- Cache with key -->
<% cache [message, 'details'] do %>
  <%= message.body %>
<% end %>
```

## Message Object Access

Access the underlying Mail::Message object:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    
    mail(to: @user.email, subject: "Welcome") do |format|
      format.html
      
      # Access message object
      message.delivery_method_options = { 
        api_key: params[:api_key]
      }
    end
  end
end
```

## Email Headers

Set custom headers on emails:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    
    headers["X-Priority"] = "1"
    headers["X-Custom-Header"] = "custom-value"
    headers["List-Unsubscribe"] = "<mailto:unsubscribe@example.com>"
    
    mail(to: @user.email, subject: "Welcome")
  end
end
```

Or use the `mail` method:

```ruby
mail(
  to: @user.email,
  subject: "Welcome",
  "X-Priority" => "1"
)
```

## Best Practices

1. **Always provide host**: Configure `default_url_options` to avoid broken links
2. **Use both formats**: Create HTML and text templates for compatibility
3. **Test templates**: Use mailer previews to validate email rendering
4. **Use full URLs**: Always use `*_url` helpers, not `*_path`
5. **Inline CSS**: Email clients don't support external stylesheets
6. **Compress images**: Minimize email size with optimized images
7. **Unsubscribe links**: Include unsubscribe mechanisms per regulations
8. **Error handling**: Use `rescue_from` to handle delivery errors
