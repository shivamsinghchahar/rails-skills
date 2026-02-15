# Model Validations

Validations are used to ensure that only valid data is persisted to the database. Active Record provides built-in validators and allows you to create custom validators for business logic.

## Presence Validation

Validates that the specified attributes are not empty.

```ruby
class User < ApplicationRecord
  validates :name, :email, presence: true
end

user = User.new
user.valid?  # => false
user.errors.full_messages  # => ["Name can't be blank", "Email can't be blank"]
```

**Options:**
- `allow_nil: true` - Skip validation if attribute is nil
- `allow_blank: true` - Skip validation if attribute is blank
- `:message` - Custom error message

```ruby
class User < ApplicationRecord
  validates :email, presence: { message: "Email is required" }
end
```

## Uniqueness Validation

Validates that the attribute's value is unique in the database.

```ruby
class User < ApplicationRecord
  validates :email, uniqueness: true
end

# If a user with email already exists, validation fails
user = User.new(email: "taken@example.com")
user.valid?  # => false if email already exists
```

**Options:**
- `:scope` - Scope uniqueness to other attributes

```ruby
class Post < ApplicationRecord
  # Slug is unique per user
  validates :slug, uniqueness: { scope: :user_id }
end
```

- `:case_sensitive` - Control case sensitivity (default: true)

```ruby
class User < ApplicationRecord
  validates :email, uniqueness: { case_sensitive: false }
end
```

## Length Validation

Validates the length of attribute values.

```ruby
class Post < ApplicationRecord
  validates :title, length: { minimum: 3, maximum: 100 }
  validates :content, length: { in: 10..5000 }
  validates :slug, length: { is: 50 }
end

post = Post.new(title: "Hi")
post.valid?  # => false (minimum is 3)
```

**Options:**
- `:minimum` - Minimum length required
- `:maximum` - Maximum length allowed
- `:in` or `:within` - Range of acceptable lengths
- `:is` - Exact length required
- `:too_short`, `:too_long` - Custom messages

## Format Validation

Validates that attribute values match a regular expression.

```ruby
class User < ApplicationRecord
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, format: { with: /\A\d{3}-\d{3}-\d{4}\z/ }
end

user = User.new(email: "invalid-email")
user.valid?  # => false
```

## Numericality Validation

Validates that attributes have only numeric values.

```ruby
class Product < ApplicationRecord
  validates :price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true }
  validates :rating, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
end
```

**Options:**
- `:greater_than`, `:greater_than_or_equal_to`
- `:less_than`, `:less_than_or_equal_to`
- `:equal_to`
- `:other_than`
- `:only_integer` - Only accept whole numbers
- `:allow_nil` - Skip if nil

## Inclusion and Exclusion Validation

Validates that attribute values are included or excluded from a list.

```ruby
class Post < ApplicationRecord
  validates :status, inclusion: { in: %w(draft published archived) }
  validates :ip_address, exclusion: { in: %w(192.168.1.1 192.168.1.2) }
end

post = Post.new(status: "invalid")
post.valid?  # => false
```

## Acceptance Validation

Validates that a checkbox attribute is accepted (useful for terms of service).

```ruby
class User < ApplicationRecord
  validates :terms_of_service, acceptance: true
end

user = User.new(terms_of_service: nil)
user.valid?  # => false

user.terms_of_service = "1"
user.valid?  # => true
```

## Custom Validations

### Custom Validator Methods

Define custom validation logic in your model.

```ruby
class User < ApplicationRecord
  validate :password_strength

  def password_strength
    if password.present? && password.length < 8
      errors.add(:password, "must be at least 8 characters")
    end
    
    if password.present? && !password.match?(/[0-9]/)
      errors.add(:password, "must contain at least one number")
    end
  end
end
```

### Custom Validator Classes

For reusable validators, create a custom validator class.

```ruby
class PasswordValidator < ActiveModel::Validator
  def validate(record)
    if record.password.blank?
      record.errors.add(:password, "can't be blank")
    elsif record.password.length < 8
      record.errors.add(:password, "must be at least 8 characters")
    end
  end
end

class User < ApplicationRecord
  validates_with PasswordValidator
end
```

### Using Callbacks for Complex Logic

For validations requiring database queries or complex logic.

```ruby
class User < ApplicationRecord
  before_validation :normalize_email
  
  validate :email_not_on_blocklist
  
  private
  
  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
  def email_not_on_blocklist
    if email.present? && EmailBlocklist.exists?(email: email)
      errors.add(:email, "is not allowed")
    end
  end
end
```

## Conditional Validations

Run validations only under specific conditions.

### Using `:if` and `:unless`

```ruby
class Post < ApplicationRecord
  validates :content, presence: true, if: :published?
  validates :published_at, presence: true, unless: :draft?
  
  validates :scheduled_at, presence: true, if: -> { status == 'scheduled' }
end

class User < ApplicationRecord
  # Only validate age if user indicates they're an adult
  validates :age, presence: true, if: :is_adult?
  
  def is_adult?
    confirmed_adult == true
  end
end
```

### Complex Conditions

```ruby
class Order < ApplicationRecord
  validates :coupon_code, presence: true, if: proc { |order|
    order.total > 100 && order.customer_type == 'regular'
  }
  
  validates :shipping_address, presence: true, if: :physical_product?
  
  def physical_product?
    items.any? { |item| item.digital == false }
  end
end
```

## Validation Callbacks

Validation callbacks are executed during the validation process.

```ruby
class User < ApplicationRecord
  # Before validation
  before_validation :downcase_email
  
  # After validation
  after_validation :log_validation_errors
  
  private
  
  def downcase_email
    self.email = email.downcase if email.present?
  end
  
  def log_validation_errors
    if invalid?
      Rails.logger.warn("User validation failed: #{errors.full_messages.join(', ')}")
    end
  end
end
```

## Working with Validation Errors

```ruby
user = User.new(email: "invalid")

if user.invalid?
  user.errors.full_messages
  # => ["Email is invalid"]
  
  user.errors[:email]
  # => ["is invalid"]
  
  user.errors.messages
  # => {email: ["is invalid"]}
  
  user.errors.count
  # => 1
end
```

## Best Practices

- **Validate at multiple levels**: Database constraints + model validations + UI validation
- **Use specific validators**: Avoid catch-all custom validation methods
- **Keep error messages user-friendly**: Avoid technical jargon
- **Test validations**: Create tests for edge cases and conditional validations
- **Avoid validation logic in controllers**: Keep validation in models
- **Use `allow_nil` and `allow_blank` appropriately**: Don't validate everything as required
- **Consider uniqueness scopes**: Prevent overly broad uniqueness constraints
- **Document custom validators**: Explain the business logic they enforce
