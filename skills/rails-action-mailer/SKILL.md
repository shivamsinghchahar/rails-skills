---
name: rails-action-mailer
description: Send emails from Rails applications with Action Mailer. Create mailer classes, build email templates, handle attachments, configure delivery methods, and test emails. Use when sending transactional emails (welcome, password reset), notifications, bulk campaigns, or emails with attachments.
---

# Rails Action Mailer

Master email delivery in Rails applications with Action Mailer, from basic setup through advanced patterns like multipart emails, attachments, and email testing.

## When to Use This Skill

- Sending transactional emails (welcome, password reset, confirmations)
- Building notification emails (order updates, alerts, reminders)
- Creating bulk email campaigns
- Handling email attachments and inline images
- Configuring SMTP, SendGrid, or other delivery services
- Testing email content and delivery
- Building email templates with HTML and text alternatives
- Managing email callbacks and error handling

## Quick Start

Generate and send a welcome email:

```bash
rails generate mailer User welcome_email
```

Create a mailer:
```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: "notifications@example.com"

  def welcome_email
    @user = params[:user]
    @url = "http://example.com/login"
    mail(to: @user.email, subject: "Welcome to My Site")
  end
end
```

Create the email template:
```erb
<!-- app/views/user_mailer/welcome_email.html.erb -->
<h1>Welcome <%= @user.name %></h1>
<p>You have successfully signed up. Log in here: <%= link_to 'login', @url %></p>
```

Send the email from a controller:
```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    if @user.save
      UserMailer.with(user: @user).welcome_email.deliver_later
      redirect_to @user, notice: "Welcome email sent"
    end
  end
end
```

## Core Topics

**Mailer Setup & Views**: See [mailers-views.md](mailers-views.md) for generating mailers, creating templates, using layouts, URL generation, and email helpers.

**Sending Emails**: See [sending-emails.md](sending-emails.md) for deliver_now vs deliver_later, multiple recipients, attachments, multipart emails, and dynamic delivery options.

**Configuration**: See [configuration.md](configuration.md) for SMTP setup, Gmail configuration, delivery methods, and environment-specific settings.

**Callbacks & Interceptors**: See [callbacks-interceptors.md](callbacks-interceptors.md) for before/after action callbacks, before/after deliver, email interception, and email observation.

**Testing & Previews**: See [testing.md](testing.md) for email previews, unit testing mailers, ActionMailer assertions, and integration testing.

**Advanced Patterns**: See [references/advanced-patterns.md](references/advanced-patterns.md) for scheduled emails with Active Job, error handling, custom delivery agents, and production best practices.

## Examples

See [examples.md](examples.md) for practical, real-world implementations including:
- Welcome and password reset emails
- Order confirmation and shipping notifications
- Bulk newsletter campaigns
- Emails with attachments and inline images
- Error handling and retry logic

## Key Concepts

### Mailers as Controllers

Mailers work similarly to controllers:
- Instance variables accessible in views
- Can use layouts and partials
- Access to `params` hash
- Actions correspond to email types
- Views in `app/views/mailer_name/`

### Parameterized Mailers

Pass data to mailers using `with`:

```ruby
UserMailer.with(user: @user, token: @token).reset_password_email
```

Access in the mailer action:
```ruby
def reset_password_email
  @user = params[:user]
  @token = params[:token]
  mail(to: @user.email, subject: "Reset Your Password")
end
```

### Delivery Methods

Control how emails are sent:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.gmail.com",
  port: 587,
  user_name: "your-email@gmail.com",
  password: "your-password",
  authentication: "plain",
  enable_starttls: true
}
```

### Active Job Integration

`deliver_later` enqueues emails as jobs:

```ruby
# Sends immediately
UserMailer.with(user: @user).welcome_email.deliver_now

# Sends in background via Active Job
UserMailer.with(user: @user).welcome_email.deliver_later

# Sends at a specific time
UserMailer.with(user: @user).welcome_email.deliver_later(wait_until: 1.hour.from_now)
```

## Connections to Other Skills

- **Rails Active Job**: Queue emails for background delivery with proper error handling and retries
- **Rails Active Record**: Query users or other models for email campaigns
- **Rails Action Controller**: Trigger emails from controller actions on create/update events
- **Rails Testing with RSpec**: Test mailers with integration tests and email assertions

## Official Resources

- [Action Mailer Basics](https://guides.rubyonrails.org/action_mailer_basics.html)
- [Action Mailer Configuration](https://guides.rubyonrails.org/configuring.html#configuring-action-mailer)
- [Testing Action Mailer](https://guides.rubyonrails.org/testing.html#testing-mailers)
- [Mail Gem](https://github.com/mikel/mail)
