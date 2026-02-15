# Callbacks and Interceptors

Managing email lifecycle with callbacks and intercepting/observing emails for cross-cutting concerns.

## Action Callbacks

Action callbacks run around email composition:

```ruby
class InvitationsMailer < ApplicationMailer
  before_action :set_inviter_and_invitee
  before_action { @account = params[:inviter].account }
  
  default to:       -> { @invitee.email },
          from:     -> { "invitations@#{@account.domain}" },
          reply_to: -> { @inviter.email }
  
  def account_invitation
    mail subject: "You're invited to #{@account.name}"
  end
  
  private
  
  def set_inviter_and_invitee
    @inviter = params[:inviter]
    @invitee = params[:invitee]
  end
end
```

### before_action

Runs before the mailer action. Useful for:
- Setting instance variables from params
- Populating defaults
- Validating prerequisites

```ruby
class UserMailer < ApplicationMailer
  before_action :load_user
  before_action :validate_email
  
  def welcome_email
    # @user is already loaded
    mail(to: @user.email, subject: "Welcome")
  end
  
  private
  
  def load_user
    @user = params[:user]
  end
  
  def validate_email
    raise "Invalid email" unless @user.email.present?
  end
end
```

### after_action

Runs after composing but before delivery. Useful for:
- Modifying the mail object
- Setting additional headers
- Dynamic configuration

```ruby
class UserMailer < ApplicationMailer
  after_action :set_delivery_options,
               :prevent_delivery_to_guests,
               :add_tracking_headers
  
  def campaign_email
    @user = params[:user]
    mail(to: @user.email, subject: "Campaign")
  end
  
  private
  
  def set_delivery_options
    if @business&.custom_smtp?
      mail.delivery_method.settings.merge!(@business.smtp_settings)
    end
  end
  
  def prevent_delivery_to_guests
    mail.perform_deliveries = false if @user&.guest?
  end
  
  def add_tracking_headers
    if @business
      headers["X-Business-ID"] = @business.id
    end
  end
end
```

### around_action

Wraps the action execution:

```ruby
class AdminMailer < ApplicationMailer
  around_action :log_delivery_time
  
  def alert
    mail(to: "admin@example.com", subject: "Alert")
  end
  
  private
  
  def log_delivery_time
    start = Time.current
    yield
    duration = Time.current - start
    Rails.logger.info("Email sent in #{duration}ms")
  end
end
```

## Delivery Callbacks

Delivery callbacks run around the actual email delivery:

### before_deliver

Runs before sending. Can abort delivery:

```ruby
class UserMailer < ApplicationMailer
  before_deliver :sandbox_non_production
  
  def notification
    @user = params[:user]
    mail(to: @user.email, subject: "Notification")
  end
  
  private
  
  def sandbox_non_production
    # Redirect staging emails to sandbox
    if Rails.env.staging?
      message.to = ["sandbox@example.com"]
    end
  end
end
```

Abort with throw:

```ruby
before_deliver do
  throw :abort if message.to.any? { |email| email.include?("@test.com") }
end
```

### around_deliver

Wrap delivery execution:

```ruby
class UserMailer < ApplicationMailer
  around_deliver :monitor_delivery
  
  def welcome_email
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome")
  end
  
  private
  
  def monitor_delivery
    start = Time.current
    yield
    duration = Time.current - start
    
    DeliveryMetric.create(
      mailer: self.class.name,
      action: action_name,
      duration: duration,
      status: "success"
    )
  rescue => e
    DeliveryMetric.create(
      mailer: self.class.name,
      action: action_name,
      duration: Time.current - start,
      status: "error",
      error: e.message
    )
    raise
  end
end
```

### after_deliver

Runs after successful delivery. No access to message:

```ruby
class UserMailer < ApplicationMailer
  after_deliver :mark_delivered,
                :log_delivery,
                :update_statistics
  
  def welcome_email
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome")
  end
  
  private
  
  def mark_delivered
    # params still available
    params[:user].update(email_sent_at: Time.current)
  end
  
  def log_delivery
    Rails.logger.info("Welcome email sent to #{params[:user].email}")
  end
  
  def update_statistics
    EmailStatistic.increment_sent
  end
end
```

## Email Interception

Intercept and modify emails before delivery:

```ruby
# lib/sandbox_interceptor.rb
class SandboxInterceptor
  def self.delivering_email(message)
    if Rails.env.staging?
      message.to = ["sandbox@example.com"]
      message.subject = "[STAGING] #{message.subject}"
    end
  end
end

# config/initializers/mail_interceptors.rb
Rails.application.configure do
  if Rails.env.staging?
    config.action_mailer.interceptors = %w[SandboxInterceptor]
  end
end
```

Common interceptor patterns:

```ruby
# Redirect to development inbox
class DevelopmentInterceptor
  def self.delivering_email(message)
    if Rails.env.development?
      message.to = ["dev@localhost"]
    end
  end
end

# Sanitize user emails
class UserEmailSanitizer
  def self.delivering_email(message)
    # Only real emails in production
    unless Rails.env.production?
      message.to = message.to.map { |email|
        email.gsub(/@.*/, "@example.com")
      }
    end
  end
end

# Add unsubscribe headers
class UnsubscribeInterceptor
  def self.delivering_email(message)
    if message.to.any?
      recipient = User.find_by(email: message.to.first)
      if recipient&.email_notifications?
        message.header["List-Unsubscribe"] =
          "<mailto:unsubscribe@example.com?subject=unsubscribe&body=#{recipient.id}>"
      end
    end
  end
end
```

Register multiple interceptors:

```ruby
# config/initializers/mail_interceptors.rb
Rails.application.configure do
  config.action_mailer.interceptors = [
    'DevelopmentInterceptor',
    'UnsubscribeInterceptor',
    'AuditInterceptor'
  ]
end
```

## Email Observation

Observer pattern for post-delivery hooks:

```ruby
# lib/email_delivery_observer.rb
class EmailDeliveryObserver
  def self.delivered_email(message)
    EmailDelivery.create(
      to: message.to.first,
      subject: message.subject,
      delivered_at: Time.current
    )
  end
end

# config/initializers/mail_observers.rb
Rails.application.configure do
  config.action_mailer.observers = %w[EmailDeliveryObserver]
end
```

### Common Observer Patterns

Log all emails:

```ruby
class EmailLogger
  def self.delivered_email(message)
    Rails.logger.info(
      "Email sent: To=#{message.to}, Subject=#{message.subject}, " \
      "Time=#{Time.current}"
    )
  end
end
```

Track delivery metrics:

```ruby
class EmailMetricsObserver
  def self.delivered_email(message)
    DeliveryMetric.create(
      recipient: message.to.first,
      subject: message.subject,
      size: message.to_s.bytesize,
      has_attachments: message.attachments.any?,
      delivered_at: Time.current
    )
  end
end
```

Send to analytics service:

```ruby
class AnalyticsObserver
  def self.delivered_email(message)
    Analytics.track('email_sent', {
      to: message.to.first,
      subject: message.subject,
      timestamp: Time.current.iso8601
    })
  end
end
```

## Callback vs Observer

Callbacks vs Interceptor/Observer:

| Feature | Callback | Interceptor | Observer |
|---------|----------|-------------|----------|
| When | Around action/delivery | Before delivery | After delivery |
| Access | Full mailer context | message object | message object |
| Use case | Setup/teardown, config | Modify email | Logging, tracking |
| Can abort | Yes (throw :abort) | Yes (modify) | No |
| Examples | Load data, validate | Sandbox, sanitize | Log, audit, metrics |

## Error Handling

Use rescue_from for error handling:

```ruby
class NotificationMailer < ApplicationMailer
  rescue_from ActiveRecord::RecordNotFound do
    # Handle gracefully
    Rails.logger.warn("Record not found for email")
  end
  
  rescue_from "SomeService::ApiError" do |exception|
    # Log and continue
    Sentry.capture_exception(exception)
  end
  
  def notification
    @user = params[:user]
    mail(to: @user.email, subject: "Notification")
  end
end
```

Error handling with after_deliver:

```ruby
class UserMailer < ApplicationMailer
  after_deliver :handle_errors
  
  def welcome_email
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome")
  rescue => e
    Rails.logger.error("Failed to send welcome email: #{e.message}")
    raise
  end
  
  private
  
  def handle_errors
    # This runs even if there were errors
  end
end
```

## Best Practices

1. **Use callbacks for setup**: Load data in before_action
2. **Use interceptors for modification**: Redirect emails in staging
3. **Use observers for tracking**: Log deliveries and metrics
4. **Keep callbacks focused**: Single responsibility per callback
5. **Handle errors gracefully**: Use rescue_from for expected failures
6. **Order matters**: Callbacks execute in registration order
7. **Test callbacks**: Mock params and verify behavior
8. **Avoid side effects**: Keep callbacks pure when possible
