# Sending Emails

Delivering emails with Action Mailer, handling multiple recipients, managing attachments, and controlling delivery timing.

## Delivery Methods

Rails provides two methods to send emails:

```ruby
# Send immediately (synchronous)
UserMailer.with(user: @user).welcome_email.deliver_now

# Queue for later delivery via Active Job (asynchronous)
UserMailer.with(user: @user).welcome_email.deliver_later
```

### deliver_now

Sends email immediately during request. Use for:
- Critical emails that must succeed
- Background jobs
- Emails that shouldn't be queued

```ruby
class SendWeeklySummary
  def call
    User.active.find_each do |user|
      UserMailer.with(user: user).weekly_summary.deliver_now
    end
  end
end
```

### deliver_later

Enqueues via Active Job for asynchronous delivery. Best practice for:
- Controller actions
- Model callbacks
- Request-driven operations
- Non-critical emails

```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    
    if @user.save
      # Queue email, don't wait for delivery
      UserMailer.with(user: @user).welcome_email.deliver_later
      redirect_to @user, notice: "User created"
    end
  end
end
```

Schedule delivery for a specific time:

```ruby
# Send in 1 hour
UserMailer.with(user: @user).welcome_email.deliver_later(wait: 1.hour)

# Send at specific time
UserMailer.with(user: @user).welcome_email.deliver_later(wait_until: 5.pm)
```

## Multiple Recipients

Send to multiple people using arrays or strings:

```ruby
class NotificationMailer < ApplicationMailer
  def order_shipped
    @order = params[:order]
    
    # Array of recipients
    mail(to: [@order.user.email, @order.shipping_contact.email])
    
    # String with comma-separated emails
    # mail(to: "user@example.com, admin@example.com")
    
    # Dynamic recipients from database
    # mail(to: User.where(preferences: { shipping_updates: true }).pluck(:email))
  end
end
```

### CC and BCC

Add carbon copy and blind carbon copy recipients:

```ruby
def admin_alert
  @alert = params[:alert]
  
  mail(
    to: @alert.recipient.email,
    cc: Admin.pluck(:email),
    bcc: "archive@example.com"
  )
end
```

## Sending with Names

Display names alongside email addresses:

```ruby
class UserMailer < ApplicationMailer
  # In from address
  default from: email_address_with_name("noreply@example.com", "My Company")
  
  def welcome_email
    @user = params[:user]
    
    # In to address
    mail(
      to: email_address_with_name(@user.email, @user.name),
      subject: "Welcome"
    )
  end
end
```

The `email_address_with_name` method returns a properly formatted address:

```ruby
# Results in: "John Doe <john@example.com>"
email_address_with_name("john@example.com", "John Doe")

# Handles nil names gracefully
email_address_with_name("john@example.com", nil)  # => "john@example.com"
```

## Attachments

### Adding File Attachments

Attach files using the `attachments` method:

```ruby
class InvoiceMailer < ApplicationMailer
  def invoice
    @invoice = params[:invoice]
    
    # Attach a file from disk
    attachments["invoice.pdf"] = File.read("/path/to/invoice.pdf")
    
    mail(to: @invoice.user.email, subject: "Your Invoice")
  end
  
  def report
    # Multiple attachments
    attachments["report.pdf"] = File.read("path/to/report.pdf")
    attachments["data.xlsx"] = File.read("path/to/data.xlsx")
    
    mail(to: "user@example.com", subject: "Monthly Report")
  end
end
```

### Custom MIME Types and Encoding

Specify custom MIME type and encoding:

```ruby
def certificate
  @user = params[:user]
  
  encoded_content = Base64.encode64(File.read("/path/to/file"))
  
  attachments["certificate.pdf"] = {
    mime_type: "application/pdf",
    encoding: "base64",
    content: encoded_content
  }
  
  mail(to: @user.email, subject: "Your Certificate")
end
```

### Inline Attachments

Embed images directly in email body:

```ruby
def newsletter
  @articles = params[:articles]
  
  # Mark as inline
  attachments.inline["logo.png"] = File.read("/path/to/logo.png")
  
  mail(to: params[:email], subject: "Newsletter")
end
```

Reference in template:

```erb
<!-- app/views/newsletter_mailer/newsletter.html.erb -->
<h1><%= image_tag attachments['logo.png'].url %></h1>

<p>With options:</p>
<%= image_tag attachments['logo.png'].url, alt: "Logo", style: "width: 200px;" %>
```

## Multipart Emails

### Automatic Multipart

When both HTML and text templates exist, Rails creates a multipart email:

```ruby
# app/views/user_mailer/welcome_email.html.erb
<h1>Welcome!</h1>

# app/views/user_mailer/welcome_email.text.erb
Welcome!
```

Calling `mail` automatically sends both versions:

```ruby
def welcome_email
  @user = params[:user]
  
  # Automatically renders both welcome_email.html.erb and welcome_email.text.erb
  mail(to: @user.email, subject: "Welcome")
end
```

### Explicit Multipart Rendering

Manually render specific formats:

```ruby
def welcome_email
  @user = params[:user]
  
  mail(to: @user.email, subject: "Welcome") do |format|
    format.html { render "custom_template" }
    format.text { render plain: "Welcome!" }
  end
end
```

### Part Order

Control the order of email parts:

```ruby
class ApplicationMailer < ActionMailer::Base
  default parts_order: ["text/plain", "text/html"]
end
```

## Emails Without Templates

Send plain text or HTML without template files:

```ruby
def quick_notification
  @message = params[:message]
  
  mail(
    to: "user@example.com",
    subject: "Notification",
    body: @message,
    content_type: "text/plain"
  )
end

def html_email
  mail(
    to: "user@example.com",
    subject: "HTML Email",
    body: "<h1>Hello!</h1>",
    content_type: "text/html"
  )
end
```

## Dynamic Delivery Options

Override SMTP settings per email for multi-tenant apps:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    @company = params[:company]
    
    # Override SMTP for this company
    delivery_options = {
      user_name: @company.smtp_username,
      password: @company.smtp_password,
      address: @company.smtp_host,
      port: @company.smtp_port
    }
    
    mail(
      to: @user.email,
      subject: "Welcome",
      delivery_method_options: delivery_options
    )
  end
end
```

## Custom Delivery Methods

Implement custom delivery for service integrations:

```ruby
class SendgridDeliveryMethod
  def initialize(settings)
    @settings = settings
  end
  
  def deliver!(mail)
    SendGrid::API.new(api_key: @settings[:api_key])
      .mail._("mail/send")
      .post(request_body: mail.to_json)
  end
end

# config/initializers/sendgrid.rb
ActionMailer::Base.add_delivery_method :sendgrid, SendgridDeliveryMethod,
  api_key: ENV['SENDGRID_API_KEY']
```

## Subject Translation

Use i18n for email subjects:

```ruby
def welcome_email
  @user = params[:user]
  
  # Subject looks in config/locales/en.yml
  # under action_mailer.user_mailer.welcome_email.subject
  mail(to: @user.email)
end
```

Translation file:

```yaml
# config/locales/en.yml
en:
  action_mailer:
    user_mailer:
      welcome_email:
        subject: "Welcome to %{app_name}"
        
      password_reset:
        subject: "Reset your password"
```

Provide variables:

```ruby
def welcome_email
  @user = params[:user]
  
  I18n.with_locale(@user.locale) do
    mail(to: @user.email, subject: t('.subject', app_name: 'MyApp'))
  end
end
```

## Email Headers

Set standard and custom headers:

```ruby
def important_notification
  @user = params[:user]
  
  mail(
    to: @user.email,
    subject: "Important",
    "X-Priority" => "1",
    "List-Unsubscribe" => "<mailto:unsubscribe@example.com>",
    "X-Custom" => "value"
  )
end
```

Or in the mailer:

```ruby
def important_notification
  @user = params[:user]
  
  headers["X-Priority"] = "1"
  headers["X-Mailer"] = "My App"
  
  mail(to: @user.email, subject: "Important")
end
```

## Testing Email Delivery

In controllers/models, capture emails:

```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    
    if @user.save
      email = UserMailer.with(user: @user).welcome_email
      
      # Inspect before sending
      email.message.parts.each do |part|
        puts part.content_type
      end
      
      email.deliver_later
    end
  end
end

# In console
irb> email = UserMailer.with(user: User.first).welcome_email
irb> email.message.subject
irb> email.message.to
irb> email.message.body
```

## Best Practices

1. **Use deliver_later**: Queue most emails asynchronously
2. **Provide both formats**: Always create HTML and text templates
3. **Test attachments**: Verify file encoding and MIME types
4. **Handle errors**: Use rescue_from for delivery failures
5. **Monitor delivery**: Log email sends for auditing
6. **Respect preferences**: Honor user email preferences
7. **Include unsubscribe**: Add unsubscribe links to bulk emails
8. **Rate limiting**: Implement backoff for high-volume sends
