# Testing and Previewing Emails

Testing mailer classes and previewing emails during development.

## Email Previews

Preview emails visually in the browser during development.

### Creating Previews

Generate preview classes in `test/mailers/previews/`:

```ruby
# test/mailers/previews/user_mailer_preview.rb
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    user = User.first || User.create!(email: "test@example.com", name: "Test User")
    UserMailer.with(user: user).welcome_email
  end
  
  def password_reset
    user = User.first || User.create!(email: "test@example.com")
    UserMailer.with(user: user, token: "reset-token-123").password_reset
  end
  
  def invoice
    invoice = Invoice.first || Invoice.create!(user: User.first, total: 99.99)
    InvoiceMailer.with(invoice: invoice).invoice
  end
end
```

Access previews at:
- `http://localhost:3000/rails/mailers`
- `http://localhost:3000/rails/mailers/user_mailer/welcome_email`
- `http://localhost:3000/rails/mailers/user_mailer/password_reset`

### Custom Preview Paths

Configure additional preview directories:

```ruby
# config/application.rb
config.action_mailer.preview_paths << "#{Rails.root}/lib/mailer_previews"
```

### Preview Best Practices

```ruby
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    # Use first existing record or create realistic test data
    order = Order.first || Order.create!(
      user: User.create!(email: "customer@example.com", name: "Jane Doe"),
      total: 99.99,
      items: [
        OrderItem.new(product_name: "Widget", quantity: 2, price: 49.99)
      ]
    )
    
    OrderMailer.with(order: order).confirmation
  end
  
  def shipped
    # Preview different scenarios
    order = Order.first || create_sample_order
    
    OrderMailer.with(order: order, tracking_number: "1Z999AA10123456784").shipped
  end
  
  private
  
  def create_sample_order
    Order.create!(
      user: User.create!(email: "test@example.com", name: "Test User"),
      total: 150.00,
      status: "pending"
    )
  end
end
```

## Unit Testing Mailers

Test mailer actions and content:

```ruby
# test/mailers/user_mailer_test.rb
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome_email" do
    user = User.create!(
      email: "user@example.com",
      name: "John Doe"
    )
    
    email = UserMailer.with(user: user).welcome_email
    
    assert_emails 1 do
      email.deliver_now
    end
    
    # Check mail attributes
    assert_equal ["user@example.com"], email.to
    assert_equal ["noreply@example.com"], email.from
    assert_match "Welcome John", email.body.encoded
  end
  
  test "password_reset_email" do
    user = User.create!(email: "user@example.com")
    token = "reset-token-123"
    
    email = UserMailer.with(user: user, reset_token: token).password_reset
    
    assert_equal ["user@example.com"], email.to
    assert email.body.encoded.include?(token)
  end
  
  test "email_with_attachment" do
    user = User.create!(email: "user@example.com")
    
    email = UserMailer.with(user: user).invoice_email
    
    assert_not email.attachments.empty?
    assert_equal "invoice.pdf", email.attachments.first.filename
  end
end
```

### Common Assertions

```ruby
class UserMailerTest < ActionMailer::TestCase
  test "mailer assertions" do
    email = UserMailer.welcome_email
    
    # Check recipients
    assert_equal ["user@example.com"], email.to
    assert email.to.include?("user@example.com")
    
    # Check sender
    assert_equal ["noreply@example.com"], email.from
    
    # Check cc/bcc
    assert email.cc.include?("admin@example.com")
    assert email.bcc.include?("archive@example.com")
    
    # Check subject
    assert_equal "Welcome!", email.subject
    assert email.subject.include?("Welcome")
    
    # Check body
    assert email.body.encoded.include?("Welcome")
    assert_match /verification link/, email.body.encoded
    
    # Check multipart
    assert email.multipart?
    assert email.text_part.present?
    assert email.html_part.present?
    
    # Check attachments
    assert email.attachments.any?
    assert_equal "document.pdf", email.attachments.first.filename
    
    # Check headers
    assert_equal "1", email.header["X-Priority"].value
  end
end
```

## RSpec Testing

With RSpec and mail matchers:

```ruby
# spec/mailers/user_mailer_spec.rb
require "rails_helper"

RSpec.describe UserMailer do
  describe "#welcome_email" do
    let(:user) { create(:user, email: "user@example.com") }
    
    subject(:mail) { UserMailer.with(user: user).welcome_email }
    
    it "renders the headers" do
      expect(mail.subject).to eq("Welcome to My Site")
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(["noreply@example.com"])
    end
    
    it "renders the body" do
      expect(mail.body.encoded).to match(user.name)
      expect(mail.body.encoded).to include("log in")
    end
    
    it "includes verification link" do
      expect(mail.body.encoded).to include(@confirmation_url)
    end
  end
  
  describe "#password_reset" do
    let(:user) { create(:user) }
    let(:token) { "reset-token-123" }
    
    subject(:mail) { UserMailer.with(user: user, token: token).password_reset }
    
    it "includes reset token" do
      expect(mail.body.encoded).to include(token)
    end
    
    it "sends to correct recipient" do
      expect(mail.to).to eq([user.email])
    end
  end
end
```

### Integration Testing

Test email delivery in full request cycle:

```ruby
# spec/requests/users_spec.rb
RSpec.describe "User Registration" do
  it "sends welcome email" do
    expect {
      post "/users", params: {
        user: { email: "new@example.com", name: "New User" }
      }
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    
    # Or test synchronously
    expect {
      post "/users", params: { user: { email: "new@example.com" } }
    }.to change { ActionMailer::Base.deliveries.count }.by(1)
    
    email = ActionMailer::Base.deliveries.last
    expect(email.to).to include("new@example.com")
  end
end
```

## Testing Delivery Methods

Verify correct delivery method is used:

```ruby
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "sends via sendgrid in production" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    
    email = UserMailer.welcome_email
    
    # Verify delivery method
    assert_equal :sendgrid, email.delivery_method.class.name
  end
  
  test "queues with active job" do
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      UserMailer.welcome_email.deliver_later
    end
  end
end
```

## Testing Callbacks

Test before/after actions and delivery callbacks:

```ruby
class CustomMailerTest < ActionMailer::TestCase
  test "before_action sets instance variables" do
    # Create test data
    inviter = create(:user)
    invitee = create(:user, email: "invitee@example.com")
    
    email = InvitationsMailer.with(
      inviter: inviter,
      invitee: invitee
    ).account_invitation
    
    # Verify before_action ran
    assert_equal invitee.email, email.to[0]
    assert email.from.include?(inviter.email)
  end
  
  test "after_deliver callback logs email" do
    expect_any_instance_of(Logger).to receive(:info).with(/Email sent/)
    
    UserMailer.welcome_email.deliver_now
  end
end
```

## Testing with Fixtures

Use fixtures for consistent test data:

```yaml
# test/fixtures/users.yml
alice:
  email: alice@example.com
  name: Alice
  
bob:
  email: bob@example.com
  name: Bob
```

```ruby
class UserMailerTest < ActionMailer::TestCase
  test "welcome email with fixture" do
    email = UserMailer.with(user: users(:alice)).welcome_email
    
    assert_equal ["alice@example.com"], email.to
    assert email.body.encoded.include?("Alice")
  end
end
```

## Testing Multipart Emails

Verify both text and HTML versions:

```ruby
class UserMailerTest < ActionMailer::TestCase
  test "multipart email" do
    email = UserMailer.welcome_email
    
    assert email.multipart?
    
    # Check HTML part
    assert email.html_part.present?
    assert email.html_part.body.encoded.include?("<h1>")
    
    # Check text part
    assert email.text_part.present?
    assert email.text_part.body.encoded.include?("Welcome")
    
    # Verify content matches
    html_body = email.html_part.body.encoded
    text_body = email.text_part.body.encoded
    
    expect(html_body).to match(text_body)
  end
end
```

## Testing Attachments

Verify attachments in emails:

```ruby
class InvoiceMailerTest < ActionMailer::TestCase
  test "email with pdf attachment" do
    invoice = create(:invoice)
    
    email = InvoiceMailer.with(invoice: invoice).invoice
    
    assert email.attachments.any?
    assert_equal "invoice.pdf", email.attachments[0].filename
    assert_equal "application/pdf", email.attachments[0].mime_type
  end
  
  test "inline image attachment" do
    email = NewsletterMailer.newsletter
    
    assert email.attachments.any?
    
    # Check inline attachment
    inline = email.attachments.find { |a| a.inline? }
    assert inline.present?
    assert_equal "logo.png", inline.filename
  end
end
```

## Testing Interceptors

Verify interceptors modify emails:

```ruby
class InterceptorTest < ActiveSupport::TestCase
  setup do
    # Register interceptor
    ActionMailer::Base.register_interceptor(SandboxInterceptor)
  end
  
  teardown do
    # Clean up
    ActionMailer::Base.unregister_interceptor(SandboxInterceptor)
  end
  
  test "sandbox interceptor redirects staging emails" do
    email = UserMailer.welcome_email
    
    expect {
      email.deliver_now
    }.to change { email.to }.from(["user@example.com"]).to(["sandbox@example.com"])
  end
end
```

## Best Practices

1. **Test both formats**: Verify HTML and text versions
2. **Use factories**: Create realistic test data with FactoryBot
3. **Test callbacks**: Verify before/after actions execute correctly
4. **Check headers**: Validate important headers are set
5. **Test attachments**: Verify files are attached correctly
6. **Mock external services**: Don't call real APIs in tests
7. **Use preview for visual check**: Manually verify styling
8. **Test error cases**: Verify error handling in mailers
