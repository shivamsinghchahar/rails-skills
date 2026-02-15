# Examples

Practical, real-world email implementations with complete working examples.

## Welcome Email with Confirmation

Common signup flow with confirmation email:

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def confirmation_email
    @user = params[:user]
    @confirmation_url = params[:confirmation_url]
    
    mail(to: @user.email, subject: "Confirm your email address")
  end
end

# app/views/user_mailer/confirmation_email.html.erb
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <style>
      body { font-family: Arial, sans-serif; }
      .container { max-width: 600px; margin: 0 auto; padding: 20px; }
      .button { display: inline-block; padding: 10px 20px; background: #0066cc; color: white; text-decoration: none; border-radius: 5px; }
      .footer { margin-top: 40px; border-top: 1px solid #ccc; padding-top: 20px; font-size: 12px; color: #666; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Welcome <%= @user.name %></h1>
      <p>Thanks for signing up! Please confirm your email address to activate your account.</p>
      
      <p style="text-align: center; margin: 30px 0;">
        <a href="<%= @confirmation_url %>" class="button">Confirm Email</a>
      </p>
      
      <p>Or copy this link: <%= @confirmation_url %></p>
      
      <p>This link expires in 24 hours.</p>
      
      <div class="footer">
        <p>If you didn't sign up for this account, you can safely ignore this email.</p>
      </div>
    </div>
  </body>
</html>

# app/views/user_mailer/confirmation_email.text.erb
Welcome <%= @user.name %>!

Thanks for signing up! Please confirm your email address:

<%= @confirmation_url %>

This link expires in 24 hours.

If you didn't sign up, you can ignore this email.

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    
    if @user.save
      confirmation_url = confirmation_url(token: @user.confirmation_token, host: request.host)
      UserMailer.with(user: @user, confirmation_url: confirmation_url).confirmation_email.deliver_later
      
      redirect_to root_path, notice: "Check your email to confirm"
    else
      render :new
    end
  end
end
```

## Password Reset Email

Secure password reset flow:

```ruby
class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @reset_url = params[:reset_url]
    @expires_at = params[:expires_at]
    
    mail(to: @user.email, subject: "Reset your password")
  end
end

# app/views/user_mailer/password_reset.html.erb
<h1>Reset Your Password</h1>

<p>We received a request to reset your password. Click the link below to set a new password:</p>

<p>
  <a href="<%= @reset_url %>" style="display: inline-block; padding: 10px 20px; background: #0066cc; color: white; text-decoration: none; border-radius: 5px;">
    Reset Password
  </a>
</p>

<p style="color: #666; font-size: 14px;">
  This link expires at <%= @expires_at.strftime("%B %d, %Y at %I:%M %p") %>
</p>

<p style="margin-top: 30px; color: #999; font-size: 12px;">
  If you didn't request this reset, you can safely ignore this email. Your password hasn't been changed.
</p>

# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  
  def generate_password_reset_token
    self.password_reset_token = SecureRandom.hex(32)
    self.password_reset_expires_at = 2.hours.from_now
    save!
  end
  
  def password_reset_expired?
    password_reset_expires_at < Time.current
  end
end

# app/controllers/passwords_controller.rb
class PasswordsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    
    if user
      user.generate_password_reset_token
      reset_url = password_reset_url(token: user.password_reset_token)
      UserMailer.with(
        user: user,
        reset_url: reset_url,
        expires_at: user.password_reset_expires_at
      ).password_reset.deliver_later
      
      redirect_to root_path, notice: "Check your email for reset link"
    else
      redirect_to root_path, notice: "If email exists, we'll send reset link"
    end
  end
  
  def update
    user = User.find_by(password_reset_token: params[:token])
    
    if user&.password_reset_expired?
      redirect_to root_path, alert: "Reset link has expired"
    elsif user&.update(password: params[:password])
      user.update(password_reset_token: nil)
      redirect_to login_path, notice: "Password updated successfully"
    else
      render :edit, alert: "Failed to update password"
    end
  end
end
```

## Order Confirmation with Attachments

E-commerce order confirmation:

```ruby
class OrderMailer < ApplicationMailer
  def confirmation
    @order = params[:order]
    @customer = @order.customer
    
    # Attach invoice
    invoice_pdf = generate_invoice_pdf(@order)
    attachments["invoice_#{@order.number}. pdf"] = invoice_pdf
    
    mail(to: @customer.email, subject: "Order Confirmation ##{@order.number}")
  end
  
  private
  
  def generate_invoice_pdf(order)
    # Use Prawn or similar to generate PDF
    pdf = Prawn::Document.new
    pdf.text "Invoice for Order #{order.number}"
    # ... more PDF content
    pdf.render
  end
end

# app/views/order_mailer/confirmation.html.erb
<h1>Thank you for your order!</h1>

<div style="margin: 20px 0; padding: 20px; background: #f5f5f5;">
  <h2>Order #<%= @order.number %></h2>
  <p><strong>Date:</strong> <%= @order.created_at.strftime("%B %d, %Y") %></p>
  <p><strong>Total:</strong> <%= number_to_currency(@order.total) %></p>
</div>

<h3>Items:</h3>
<table style="width: 100%; border-collapse: collapse;">
  <tr style="background: #f9f9f9;">
    <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Product</th>
    <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Qty</th>
    <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Price</th>
  </tr>
  <% @order.items.each do |item| %>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd;"><%= item.product_name %></td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: right;"><%= item.quantity %></td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: right;"><%= number_to_currency(item.price) %></td>
    </tr>
  <% end %>
</table>

<p style="margin-top: 20px;">
  Your invoice is attached. 
  <a href="<%= order_url(@order) %>">View order details</a>
</p>

# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    
    if @order.save
      OrderMailer.with(order: @order).confirmation.deliver_later
      redirect_to order_path(@order), notice: "Order confirmed!"
    else
      render :new
    end
  end
end
```

## Notification Email

Simple notification email:

```ruby
class NotificationMailer < ApplicationMailer
  def notify
    @user = params[:user]
    @message = params[:message]
    @action_url = params[:action_url]
    
    mail(to: @user.email, subject: @message.subject)
  end
end

# app/views/notification_mailer/notify.html.erb
<h2><%= @message.title %></h2>

<p><%= simple_format(@message.body) %></p>

<% if @action_url.present? %>
  <p style="margin: 20px 0;">
    <a href="<%= @action_url %>" style="padding: 10px 20px; background: #0066cc; color: white; text-decoration: none; border-radius: 5px; display: inline-block;">
      <%= @message.action_label %>
    </a>
  </p>
<% end %>

# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user
  
  def deliver
    action_url = case action_type
                 when 'comment'
                   post_url(resource)
                 when 'like'
                   profile_url(resource.user)
                 else
                   nil
                 end
    
    NotificationMailer.with(
      user: user,
      message: self,
      action_url: action_url
    ).notify.deliver_later(wait: 1.hour)  # Batch notifications
  end
end
```

## Newsletter

Bulk email campaign:

```ruby
class NewsletterMailer < ApplicationMailer
  def monthly_digest
    @subscriber = params[:subscriber]
    @articles = Article.recent.limit(10)
    @unsubscribe_url = params[:unsubscribe_url]
    
    mail(to: @subscriber.email, subject: "Your Monthly Digest")
  end
end

# app/views/newsletter_mailer/monthly_digest.html.erb
<h1>Your Monthly Digest</h1>

<p>Hi <%= @subscriber.first_name %>,</p>

<p>Here are this month's top articles:</p>

<% @articles.each do |article| %>
  <div style="margin: 20px 0; padding: 15px; border-left: 4px solid #0066cc;">
    <h3><a href="<%= article_url(article) %>"><%= article.title %></a></h3>
    <p><%= truncate(article.body, length: 200) %></p>
    <p><a href="<%= article_url(article) %>">Read more →</a></p>
  </div>
<% end %>

<hr style="margin: 40px 0;">

<p style="font-size: 12px; color: #666;">
  <a href="<%= @unsubscribe_url %>">Unsubscribe from this newsletter</a>
</p>

# app/jobs/send_newsletter_job.rb
class SendNewsletterJob < ApplicationJob
  queue_as :newsletters
  
  def perform(newsletter_id)
    newsletter = Newsletter.find(newsletter_id)
    
    Subscriber.active.find_each(batch_size: 1000) do |subscriber|
      unsubscribe_url = newsletter_unsubscribe_url(
        token: subscriber.unsubscribe_token
      )
      
      NewsletterMailer.with(
        subscriber: subscriber,
        unsubscribe_url: unsubscribe_url
      ).monthly_digest.deliver_later
      
      sleep(0.1)  # Rate limiting
    end
  end
end

# app/controllers/newsletters_controller.rb
class NewslettersController < ApplicationController
  def send_newsletter
    @newsletter = Newsletter.find(params[:id])
    SendNewsletterJob.perform_later(@newsletter.id)
    
    redirect_to @newsletter, notice: "Newsletter queued for delivery"
  end
end
```

## Multi-part Email (HTML + Text)

Email with multiple format support:

```ruby
class PromotionalMailer < ApplicationMailer
  def promotion
    @user = params[:user]
    @offer = params[:offer]
    
    mail(to: @user.email, subject: @offer.title) do |format|
      format.html { render action: 'promotion' }
      format.text { render action: 'promotion' }
    end
  end
end

# app/views/promotional_mailer/promotion.html.erb
<h1><%= @offer.title %></h1>
<p>Save <%= number_to_percentage(@offer.discount) %>!</p>
<a href="<%= offer_url(@offer) %>">Claim Offer</a>

# app/views/promotional_mailer/promotion.text.erb
<%= @offer.title %>

Save <%= number_to_percentage(@offer.discount) %>!

Claim your offer: <%= offer_url(@offer) %>
```

## Email with Inline Images

Email with embedded images:

```ruby
class WelcomeMailer < ApplicationMailer
  def welcome_with_logo
    @user = params[:user]
    
    attachments.inline['logo.png'] = File.read('app/assets/images/logo.png')
    attachments.inline['welcome-banner.jpg'] = File.read('app/assets/images/welcome-banner.jpg')
    
    mail(to: @user.email, subject: "Welcome!")
  end
end

# app/views/welcome_mailer/welcome_with_logo.html.erb
<div style="text-align: center;">
  <%= image_tag attachments['logo.png'].url, alt: 'Logo', style: 'width: 200px;' %>
</div>

<h1>Welcome <%= @user.name %></h1>

<%= image_tag attachments['welcome-banner.jpg'].url, alt: 'Welcome', style: 'width: 100%;' %>

<p>We're excited to have you on board!</p>
```
