# Patterns

Design patterns, best practices, and common pitfalls when working with Active Record models.

## Callbacks

Callbacks are hooks into the Active Record lifecycle that allow you to trigger logic at specific times.

### Lifecycle Callbacks

```ruby
class User < ApplicationRecord
  # Creation
  before_create :set_default_role
  after_create :send_welcome_email
  
  # Update
  before_update :log_changes
  after_update :invalidate_cache
  
  # Validation
  before_validation :normalize_phone
  after_validation :check_business_rules
  
  # Deletion
  before_destroy :archive_data
  after_destroy :notify_team
  
  # Commit (after transaction succeeds)
  after_commit :publish_event
  after_rollback :log_transaction_failure
  
  private
  
  def set_default_role
    self.role = 'user' if role.blank?
  end
  
  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end
  
  def normalize_phone
    self.phone = phone.gsub(/\D/, '') if phone.present?
  end
end
```

### Callback Ordering and Conditions

```ruby
class Order < ApplicationRecord
  # Conditional callbacks
  before_save :calculate_total, if: :items_changed?
  
  # Multiple callbacks
  before_create :set_order_number
  before_create :apply_default_discount
  before_create :check_inventory
  
  # Skip callbacks when needed
  def self.bulk_update_status(ids, status)
    update_all(["status = ?", status])  # Callbacks NOT triggered
  end
  
  # Or use update_column to skip validation and callbacks
  order.update_column(:status, 'shipped')
end
```

### Best Practices for Callbacks

```ruby
# DO: Keep callbacks focused and testable
class User < ApplicationRecord
  after_create { WelcomeJob.perform_later(id) }
end

# DON'T: Complex logic in callbacks
class User < ApplicationRecord
  after_create do
    # Don't do complex business logic here
    send_email
    create_subscription
    notify_partners
  end
end

# Better: Delegate to services or jobs
class User < ApplicationRecord
  after_create :enqueue_onboarding
  
  private
  
  def enqueue_onboarding
    UserOnboardingJob.perform_later(id)
  end
end
```

## Soft Deletes

Implement soft deletes to "delete" records without removing them from the database.

```ruby
# Migration
create_table :posts do |t|
  t.string :title
  t.text :content
  t.datetime :deleted_at  # Soft delete timestamp
  t.timestamps
end

# Model
class Post < ApplicationRecord
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  
  def soft_delete
    update(deleted_at: Time.current)
  end
  
  def restore
    update(deleted_at: nil)
  end
  
  def permanently_delete
    really_destroy!
  end
end

# Usage
post = Post.find(1)
post.soft_delete  # Mark as deleted
Post.active  # Doesn't include soft-deleted posts
Post.deleted  # Only soft-deleted posts

post.restore  # Restore from soft delete
post.permanently_delete  # Actually remove from database
```

### Using the paranoia Gem

```ruby
# Gemfile
gem 'paranoia'

# Model
class Post < ApplicationRecord
  acts_as_paranoid
end

# Usage
post = Post.find(1)
post.destroy  # Soft delete (sets deleted_at)
Post.all  # Doesn't include soft-deleted posts
Post.with_deleted  # Includes soft-deleted
Post.only_deleted  # Only soft-deleted
post.restore  # Un-soft-delete
```

## Optimistic Locking

Prevent race conditions when multiple processes update the same record simultaneously.

```ruby
# Migration
create_table :articles do |t|
  t.string :title
  t.integer :lock_version, default: 0  # Optimistic lock column
  t.timestamps
end

# Model
class Article < ApplicationRecord
  # Automatically uses lock_version
end

# Usage
article1 = Article.find(1)
article2 = Article.find(1)

article1.update(title: "New Title")  # Updates lock_version to 1

article2.update(title: "Another Title")
# Raises ActiveRecord::StaleObjectError - version mismatch
```

## Database Transactions

Ensure data consistency with transactions.

```ruby
class Order < ApplicationRecord
  def place_order
    ActiveRecord::Base.transaction do
      update(status: 'processing')
      OrderItems.create(order_id: id, items: items)
      Payment.charge(amount, payment_method)
      # If any line raises an exception, all changes are rolled back
    end
  end
end

# Nested transactions (savepoints)
ActiveRecord::Base.transaction do
  user.update(balance: user.balance - 100)
  
  begin
    ActiveRecord::Base.transaction do
      transaction_record.update(status: 'pending')
      process_payment(amount)
    end
  rescue PaymentError => e
    # Handle payment failure without rolling back user.update above
    log_error(e)
  end
end
```

## Counter Caching

Cache association counts to improve performance.

```ruby
# Migration for user_posts table
create_table :posts do |t|
  t.references :user, foreign_key: true
  t.integer :posts_count, default: 0
  t.timestamps
end

# Model
class User < ApplicationRecord
  has_many :posts, counter_cache: true
end

class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
end

# Usage
user = User.find(1)
user.posts_count  # Cached value, no COUNT query
user.posts.create(title: "New Post")  # posts_count incremented automatically
```

## Denormalization Patterns

Cache calculated values in the database.

```ruby
class Order < ApplicationRecord
  has_many :items, class_name: 'OrderItem'
  
  before_save :calculate_totals
  
  private
  
  def calculate_totals
    self.subtotal = items.sum(:price)
    self.tax = subtotal * TAX_RATE
    self.total = subtotal + tax
  end
end

# Alternative: Lazy calculation
class User < ApplicationRecord
  has_many :posts
  
  def posts_count_cached
    read_attribute(:posts_count) || posts.count
  end
end
```

## Enum Attributes

Use enums for status fields and similar attributes.

```ruby
class Post < ApplicationRecord
  enum status: { draft: 0, published: 1, archived: 2 }
  enum visibility: { private: 0, internal: 1, public: 2 }
end

# Usage
post = Post.new
post.status = :draft
post.draft?  # => true
post.published?  # => false

Post.draft  # All drafts
Post.where(status: :draft)  # Same as above

# Scopes work
post.update(status: :published)
Post.published  # Automatically created scope
```

## STI vs Polymorphism

Choose based on your data structure. See [inheritance.md](inheritance.md) for STI patterns and [associations.md](associations.md) for polymorphic associations.

## N+1 Query Prevention

### Identifying the Problem

```ruby
# BAD: N+1 query
@users = User.limit(10)
@users.each do |user|
  puts user.profile.bio  # 1 + 10 queries
end

# GOOD
@users = User.includes(:profile).limit(10)
@users.each do |user|
  puts user.profile.bio  # 2 queries total
end
```

### Strategic Preloading

```ruby
class PostsController < ApplicationController
  def index
    # Eager load what you know you need
    @posts = Post.includes(:author, :category, comments: :author)
  end
  
  # Avoid over-eager-loading
  def show
    @post = Post.includes(comments: :author).find(params[:id])
  end
end
```

See [querying.md](querying.md) for detailed eager loading patterns.

## Validation and Save Callbacks

Understand the difference between them:

```ruby
class User < ApplicationRecord
  before_validation :set_defaults  # Runs before .valid?
  after_validation :log_errors     # Runs after validation
  before_save :final_check         # Runs before save
  after_save :clear_cache          # Runs after save
  
  validates :name, presence: true
end

# Calling update runs: before_validation -> validate -> after_validation -> before_save -> save -> after_save
user.update(name: "John")
```

## Common Pitfalls

### Returning false in Callbacks

```ruby
# BAD: Returning false halts the callback chain
class Post < ApplicationRecord
  before_save :check_something
  
  def check_something
    return false if invalid_condition  # Silently cancels save!
  end
end

# GOOD: Raise an error explicitly
class Post < ApplicationRecord
  before_save :check_something
  
  def check_something
    raise "Invalid condition" if invalid_condition  # Clear error
  end
end
```

### Callbacks in Loops

```ruby
# BAD: Triggers callback for each record
10.times { User.create(name: "User") }

# GOOD: Bulk insert without callbacks if appropriate
User.create([
  { name: "User 1" },
  { name: "User 2" }
])

# Or disable callbacks temporarily
User.create!(name: "User") { |user| user.skip_validation = true } rescue retry
```

### Over-Reliance on Callbacks

```ruby
# BAD: Complex logic in callbacks
class Order < ApplicationRecord
  after_create do
    User.increment_counter(:orders_count, user_id)
    Inventory.decrement_for_order(self)
    Email.send_confirmation(self)
  end
end

# GOOD: Separate concerns
class Order < ApplicationRecord
  after_create_commit :enqueue_order_processing
  
  private
  
  def enqueue_order_processing
    OrderProcessingJob.perform_later(id)
  end
end
```

## Testing Patterns

```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'callbacks' do
    it 'sends welcome email after creation' do
      expect(UserMailer).to receive(:welcome)
      User.create(name: 'John', email: 'john@example.com')
    end
  end
  
  describe 'associations' do
    it 'deletes posts when user is deleted' do
      user = create(:user)
      create(:post, user: user)
      
      expect { user.destroy }.to change(Post, :count).by(-1)
    end
  end
end
```

## Best Practices Summary

- **Keep callbacks small and focused**: Delegate complex logic to services
- **Prefer `after_commit` for side effects**: Ensures transaction success
- **Test callbacks thoroughly**: They're easy to break
- **Use transactions for data consistency**: Prevent partial updates
- **Eager load associations**: Always prevent N+1 queries
- **Document complex patterns**: Soft deletes, denormalization, STI need explanation
- **Consider services over callbacks**: For complex workflows
- **Monitor performance**: Use query analysis tools regularly
