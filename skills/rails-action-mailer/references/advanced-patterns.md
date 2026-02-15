# Advanced Patterns and Real-World Examples

Real-world email implementations, scheduled emails, error handling, and production patterns.

## Scheduled Emails with Active Job

Send emails at specific times using Active Job:

```ruby
class UserMailer < ApplicationMailer
  def daily_digest
    @user = params[:user]
    @articles = Article.recent.for_user(@user)
    
    mail(to: @user.email, subject: "Your Daily Digest")
  end
end

# Schedule via Active Job
class ScheduleDailyDigestJob < ApplicationJob
  queue_as :default
  
  def perform
    User.where(digest_enabled: true).find_each do |user|
      UserMailer.with(user: user).daily_digest.deliver_later(
        wait_until: 9.am
      )
    end
  end
end

# Run nightly
# config/clock.rb
every 1.day, at: '8:59am' do
  ScheduleDailyDigestJob.perform_later
end
```

## Bulk Email Campaigns

Send newsletters or promotions to many users:

```ruby
class NewsletterMailer < ApplicationMailer
  def campaign
    @campaign = params[:campaign]
    @recipient = params[:recipient]
    
    mail(
      to: email_address_with_name(@recipient.email, @recipient.name),
      subject: @campaign.subject
    )
  end
end

class SendNewsletterJob < ApplicationJob
  queue_as :newsletters
  sidekiq_options retry: 3, lock: :until_executed
  
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    
    # Send in batches to avoid overwhelming the server
    campaign.recipients.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |recipient|
        NewsletterMailer.with(
          campaign: campaign,
          recipient: recipient
        ).campaign.deliver_later
      end
      
      # Rate limiting
      sleep(1)
    end
    
    campaign.update(sent_at: Time.current)
  end
end

# Trigger from controller
class CampaignsController < ApplicationController
  def send_campaign
    @campaign = Campaign.find(params[:id])
    SendNewsletterJob.perform_later(@campaign.id)
    redirect_to @campaign, notice: "Campaign queued for delivery"
  end
end
```

## Error Handling and Retries

Handle delivery failures gracefully:

```ruby
class UserMailer < ApplicationMailer
  rescue_from StandardError do |exception|
    Sentry.capture_exception(exception)
    # Could also log, notify admin, etc.
  end
  
  def welcome_email
    @user = params[:user]
    
    begin
      mail(to: @user.email, subject: "Welcome")
    rescue Net::SMTPAuthenticationError => e
      Rails.logger.error("SMTP auth failed: #{e.message}")
      # Retry with alternate SMTP server
      retry_with_alternate_smtp
    end
  end
  
  private
  
  def retry_with_alternate_smtp
    # Implementation to retry with backup SMTP
  end
end

# With Active Job retry logic
class EmailDeliveryJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  discard_on ActionMailer::MessageDelivered
  
  def perform(mailer, method_name, delivery_method, params)
    # Active Job automatically retries on StandardError
    super
  end
end
```

## Multi-Tenant Email Configuration

Send from different domains per tenant:

```ruby
class UserMailer < ApplicationMailer
  before_action :set_tenant
  
  default from: -> { "notifications@#{@tenant.mail_domain}" }
  
  def welcome_email
    @user = params[:user]
    @tenant = @user.tenant
    
    mail(to: @user.email, subject: "Welcome to #{@tenant.name}")
  end
  
  private
  
  def set_tenant
    @tenant = params[:tenant] || params[:user].tenant
  end
end

# Dynamic SMTP per tenant
class TenantMailer < ApplicationMailer
  after_action :set_tenant_smtp
  
  private
  
  def set_tenant_smtp
    tenant = params[:tenant]
    
    if tenant.custom_smtp_configured?
      mail.delivery_method.settings.merge!(
        address: tenant.smtp_host,
        port: tenant.smtp_port,
        user_name: tenant.smtp_username,
        password: tenant.smtp_password
      )
    end
  end
end
```

## Email Audit Logging

Track all emails sent:

```ruby
# lib/email_audit_observer.rb
class EmailAuditObserver
  def self.delivered_email(message)
    EmailAudit.create!(
      recipients: message.to.join(", "),
      subject: message.subject,
      body_preview: message.text_part&.body&.to_s&.truncate(500),
      mailer_class: message.delivery_method_options&.dig(:mailer),
      delivered_at: Time.current,
      message_id: message.message_id,
      size_bytes: message.to_s.bytesize,
      has_attachments: message.attachments.any?
    )
  end
end

# config/initializers/mail_observers.rb
Rails.application.configure do
  config.action_mailer.observers = %w[EmailAuditObserver]
end

# Query and report on emails
class EmailAudit < ApplicationRecord
  scope :by_subject, ->(subject) { where("subject ILIKE ?", "%#{subject}%") }
  scope :to_recipient, ->(email) { where("recipients ILIKE ?", "%#{email}%") }
  scope :recent, -> { order(created_at: :desc) }
  
  def self.delivery_report(start_date, end_date)
    where(created_at: start_date..end_date).group_by(&:mailer_class)
  end
end
```

## Email Unsubscribe Management

Implement proper unsubscribe handling:

```ruby
# lib/unsubscribe_interceptor.rb
class UnsubscribeInterceptor
  def self.delivering_email(message)
    return unless message.to.any?
    
    recipient = User.find_by(email: message.to.first)
    return unless recipient
    
    # Add unsubscribe link header (RFC 2369)
    message.header["List-Unsubscribe"] =
      "<#{unsubscribe_url(recipient)}, mailto:unsubscribe@example.com>"
    
    # Add unsubscribe link in footer
    unless message.body.to_s.include?("unsubscribe")
      footer = render_unsubscribe_footer(recipient)
      message.body.to_s << "\n\n" << footer
    end
  end
  
  private
  
  def self.unsubscribe_url(user)
    "https://example.com/emails/unsubscribe/#{user.unsubscribe_token}"
  end
  
  def self.render_unsubscribe_footer(user)
    "Manage your email preferences: #{unsubscribe_url(user)}"
  end
end

# Controller to handle unsubscribe
class EmailPreferencesController < ApplicationController
  def unsubscribe
    user = User.find_by(unsubscribe_token: params[:token])
    
    if user
      user.update(email_notifications: false)
      redirect_to root_path, notice: "You've been unsubscribed"
    else
      render_404
    end
  end
end
```

## Transactional Email Best Practices

Pattern for critical transactional emails:

```ruby
class TransactionMailer < ApplicationMailer
  # Ensure these emails are always sent
  after_action :ensure_delivery
  
  def payment_confirmation
    @order = params[:order]
    
    mail(
      to: @order.user.email,
      subject: "Order Confirmation ##{@order.id}",
      template_path: "transactional_emails"
    )
  end
  
  def password_reset
    @user = params[:user]
    @token = params[:token]
    
    # Critical - must be sent
    mail(
      to: @user.email,
      subject: "Reset Your Password",
      priority: "urgent"
    )
  end
  
  private
  
  def ensure_delivery
    # Log all transactional emails
    TransactionLog.create!(
      email: message.to.first,
      subject: message.subject,
      type: action_name,
      status: "sent"
    )
  end
end
```

## Email Testing in Development

Preview and test emails locally:

```ruby
# config/environments/development.rb
Rails.application.configure do
  # Use letter_opener to automatically open emails in browser
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
  
  # Or write to file
  # config.action_mailer.delivery_method = :file
  # config.action_mailer.file_settings = {
  #   location: Rails.root.join('tmp/mails')
  # }
end

# Use deliveries array in console
rails console
> UserMailer.with(user: User.first).welcome_email.deliver_now
> ActionMailer::Base.deliveries.last.to
> ActionMailer::Base.deliveries.clear
```

## Email Throttling

Rate limit email sends:

```ruby
class RateLimitedMailer < ApplicationMailer
  include ActionMailer::RateLimiting
  
  # Max 10 emails per minute
  rate_limit to: 10, per_minute: 1
  
  def notification
    mail(to: params[:email], subject: "Notification")
  end
  
  def marketing_email
    # Different rate limits per action
    rate_limit to: 100, per_minute: 1
    
    mail(to: params[:email], subject: "Marketing")
  end
end

# Or manual implementation
class ThrottledMailer < ApplicationMailer
  def send_batch(users)
    users.each do |user|
      ThrottledMailJob.set(wait: calculate_delay(user)).perform_later(user.id)
    end
  end
  
  private
  
  def calculate_delay(user)
    # Spread sends across time
    batch_size = 100
    position = User.where("id <= ?", user.id).count
    (position / batch_size).minutes
  end
end
```

## Custom Delivery Services

Integration with third-party email services:

```ruby
# lib/postmark_delivery_method.rb
class PostmarkDeliveryMethod
  def initialize(settings)
    @client = Postmark::ApiClient.new(settings[:api_token])
  end
  
  def deliver!(mail)
    message = {
      from: mail.from.first,
      to: mail.to.join(','),
      subject: mail.subject,
      html_body: mail.html_part&.body&.to_s,
      text_body: mail.text_part&.body&.to_s,
      track_opens: true,
      track_links: "HtmlAndText"
    }
    
    @client.deliver(message)
  end
end

# config/initializers/postmark.rb
ActionMailer::Base.add_delivery_method :postmark, PostmarkDeliveryMethod,
  api_token: ENV['POSTMARK_API_TOKEN']

# config/environments/production.rb
config.action_mailer.delivery_method = :postmark
```

## Email Analytics

Track email opens and clicks:

```ruby
class AnalyticsMailer < ApplicationMailer
  after_deliver :track_send
  
  def newsletter
    @newsletter = params[:newsletter]
    @recipient = params[:recipient]
    
    # Add tracking pixel
    add_tracking_pixel(@recipient)
    
    # Rewrite links with tracking
    @tracking_token = generate_tracking_token(@recipient)
    
    mail(to: @recipient.email, subject: @newsletter.subject)
  end
  
  private
  
  def add_tracking_pixel(recipient)
    tracking_url = email_tracking_url(recipient)
    # Append 1x1 pixel to email
  end
  
  def track_send
    EmailMetric.create!(
      recipient: message.to.first,
      event: "sent",
      timestamp: Time.current
    )
  end
  
  def generate_tracking_token(recipient)
    SecureRandom.hex(16)
  end
end

# Webhook to track opens
class EmailMetricsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def track_open
    metric = EmailMetric.find_by(token: params[:token])
    metric&.update(opened_at: Time.current) if metric
    
    # Return 1x1 pixel
    send_data(
      Base64.decode64("R0lGODlhAQABAJAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="),
      type: 'image/gif',
      disposition: 'inline'
    )
  end
end
```

## Best Practices Summary

1. **Use deliver_later for most emails**: Queue asynchronously
2. **Handle errors gracefully**: Implement retry logic and error tracking
3. **Track all deliveries**: Audit logs for compliance
4. **Provide unsubscribe**: Always include way to opt-out
5. **Test before production**: Use previews and mailer tests
6. **Monitor deliverability**: Track bounces and complaints
7. **Rate limit sends**: Prevent overwhelming recipients
8. **Use credentials**: Store API keys securely
