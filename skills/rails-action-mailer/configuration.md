# Configuration and Delivery Methods

Configuring Action Mailer for different environments and delivery services.

## Default Configuration

Set defaults globally in ApplicationMailer:

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "noreply@example.com",
          "X-Mailer" => "My App",
          "X-Priority" => "3"
          
  layout "mailer"
  
  # Or use Proc for dynamic values
  default from: -> { "notifications@#{Rails.env}.example.com" }
end
```

Application-level configuration:

```ruby
# config/application.rb
config.action_mailer.default_url_options = { host: "example.com", protocol: "https" }
config.action_mailer.asset_host = "https://cdn.example.com"
config.action_mailer.raise_delivery_errors = true
config.action_mailer.perform_deliveries = true
config.action_mailer.preview_paths << "#{Rails.root}/lib/mailer_previews"
```

## Environment-Specific Configuration

### Development

Test without actually sending:

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = false
  
  # Preview emails at http://localhost:3000/rails/mailers
  config.action_mailer.show_previews = true
  config.action_mailer.preview_paths = ["#{Rails.root}/test/mailers/previews"]
  
  config.action_mailer.default_url_options = { host: "localhost:3000", protocol: "http" }
end
```

Or capture emails:

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
# Automatically opens emails in your browser after sending
```

Install and configure letter_opener:

```bash
gem 'letter_opener', group: :development
```

### Test

Prevent emails from leaving in tests:

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = { host: "test.example.com" }
end
```

### Production

Send via SMTP or delivery service:

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  
  config.action_mailer.default_url_options = { host: "example.com", protocol: "https" }
  config.action_mailer.asset_host = "https://cdn.example.com"
  
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_ADDRESS'],
    port: ENV['SMTP_PORT'],
    domain: "example.com",
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: "plain",
    enable_starttls: true,
    open_timeout: 5,
    read_timeout: 5
  }
end
```

## SMTP Delivery Method

Standard SMTP configuration:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:         "smtp.example.com",
  port:            587,
  domain:          "example.com",
  user_name:       "username@example.com",
  password:        "password",
  authentication:  "plain",
  enable_starttls: true,
  open_timeout:    5,
  read_timeout:    5
}
```

Using environment variables:

```ruby
# config/environments/production.rb
config.action_mailer.smtp_settings = {
  address:        ENV['SMTP_HOST'],
  port:           ENV['SMTP_PORT'],
  domain:         ENV['SMTP_DOMAIN'],
  user_name:      ENV['SMTP_USERNAME'],
  password:       ENV['SMTP_PASSWORD'],
  authentication: ENV['SMTP_AUTH'] || "plain",
  enable_starttls_auto: true
}
```

### Gmail Configuration

Use Gmail's SMTP server:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:         "smtp.gmail.com",
  port:            587,
  domain:          "example.com",
  user_name:       Rails.application.credentials.dig(:gmail, :username),
  password:        Rails.application.credentials.dig(:gmail, :password),
  authentication:  "plain",
  enable_starttls: true
}
```

For 2-factor authentication, use an [app password](https://myaccount.google.com/apppasswords):

```bash
# In credentials
EDITOR=vim rails credentials:edit

# Add:
gmail:
  username: your-email@gmail.com
  password: your-app-password  # Not your Google password
```

## Sendmail Delivery Method

Use system sendmail command:

```ruby
config.action_mailer.delivery_method = :sendmail
config.action_mailer.sendmail_settings = {
  location: '/usr/sbin/sendmail',
  arguments: ['-i', '-t', '-X /tmp/mails.log']
}
```

Common locations:
- Linux: `/usr/sbin/sendmail`
- macOS: `/usr/sbin/sendmail`
- Postfix: Usually `/usr/sbin/sendmail` (symlink)

## File Delivery Method

Write emails to files for testing:

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :file
config.action_mailer.file_settings = {
  location: Rails.root.join('tmp/mails')
}
```

## Test Delivery Method

Capture emails for testing (default in test environment):

```ruby
# config/environments/test.rb
config.action_mailer.delivery_method = :test
```

Access sent emails in tests:

```ruby
# Check that email was sent
expect(ActionMailer::Base.deliveries.count).to eq(1)

# Inspect email details
email = ActionMailer::Base.deliveries.last
expect(email.to).to include("user@example.com")
expect(email.subject).to include("Welcome")
```

Clear emails between tests:

```ruby
before(:each) do
  ActionMailer::Base.deliveries.clear
end
```

## Custom Delivery Methods

Create custom delivery methods for service integrations:

```ruby
# lib/sendgrid_delivery.rb
class SendgridDelivery
  def initialize(settings)
    @api_key = settings[:api_key]
    @from = settings[:from]
  end
  
  def deliver!(mail)
    client = SendGrid::API.new(api_key: @api_key)
    
    message = SendGrid::Mail.new(
      from: Mail::Address.new(@from),
      subject: mail.subject,
      to: mail.to,
      plain_text_content: mail.text_part&.body&.to_s,
      html_content: mail.html_part&.body&.to_s
    )
    
    client.mail._("mail/send").post(request_body: message.to_json)
  end
end

# config/initializers/sendgrid.rb
ActionMailer::Base.add_delivery_method :sendgrid, SendgridDelivery,
  api_key: ENV['SENDGRID_API_KEY'],
  from: 'noreply@example.com'

# config/environments/production.rb
config.action_mailer.delivery_method = :sendgrid
```

## Perform Deliveries

Control whether emails are actually sent:

```ruby
# Useful for disabling during migrations or maintenance
config.action_mailer.perform_deliveries = false

# Enable for specific block
mail_delivery_disabled = ActionMailer::Base.perform_deliveries
ActionMailer::Base.perform_deliveries = true
UserMailer.welcome_email.deliver_now
ActionMailer::Base.perform_deliveries = mail_delivery_disabled
```

## Caching Configuration

Enable fragment caching in mailer views:

```ruby
# config/environments/production.rb
config.action_mailer.perform_caching = true
```

## URL Generation

Configure default URL options:

```ruby
# config/application.rb
config.action_mailer.default_url_options = { 
  host: "example.com", 
  protocol: "https"
}

# Or per environment
# config/environments/development.rb
config.action_mailer.default_url_options = { 
  host: "localhost:3000", 
  protocol: "http"
}

# config/environments/production.rb
config.action_mailer.default_url_options = { 
  host: "example.com", 
  protocol: "https"
}
```

## Error Handling Configuration

```ruby
# config/environments/production.rb
# Raise errors instead of silently failing
config.action_mailer.raise_delivery_errors = true

# Control whether to raise when delivery fails
config.action_mailer.delivery_method_options = {
  raise_errors: true
}
```

## Delivery Method Options

Pass per-email delivery options:

```ruby
class UserMailer < ApplicationMailer
  def welcome_email
    @user = params[:user]
    
    # Override delivery method for this email
    mail(
      to: @user.email,
      subject: "Welcome",
      delivery_method_options: {
        user_name: "custom@example.com",
        password: "custom_password"
      }
    )
  end
end
```

## Configuration in Credentials

Store sensitive config in Rails credentials:

```bash
EDITOR=vim rails credentials:edit
```

```yaml
smtp:
  host: smtp.gmail.com
  port: 587
  username: your-email@gmail.com
  password: your-app-password

sendgrid:
  api_key: SG.xxxxx
```

Access in configuration:

```ruby
# config/environments/production.rb
smtp = Rails.application.credentials.dig(:smtp)

config.action_mailer.smtp_settings = {
  address: smtp[:host],
  port: smtp[:port],
  user_name: smtp[:username],
  password: smtp[:password],
  authentication: 'plain',
  enable_starttls: true
}
```

## Best Practices

1. **Use credentials**: Never hardcode credentials in code
2. **Environment-specific config**: Different settings per environment
3. **Test early**: Preview emails during development
4. **Use deliver_later**: Queue most emails asynchronously
5. **Monitor logs**: Track delivery success/failure
6. **Set timeouts**: Configure reasonable open/read timeouts
7. **TLS support**: Always enable STARTTLS when available
8. **Backup delivery**: Have fallback delivery method configured
