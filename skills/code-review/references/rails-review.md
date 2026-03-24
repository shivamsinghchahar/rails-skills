# Rails Code Review

Stack-specific review guidance for Ruby on Rails applications.

## Stack Detection Patterns

Files indicating Rails scope:
- `*.rb` in `app/models/`, `app/controllers/`, `app/jobs/`, `app/mailers/`, `app/channels/`
- `db/migrate/*`, `config/routes.rb`, `config/application.rb`
- `config/initializers/*`

## Rails-Specific Red Flags

| Area | Anti-Pattern | Impact |
|------|--------------|--------|
| Models | Missing `inverse_of` on associations | N+1, inconsistent objects |
| Controllers | Logic in controllers | Hard to test |
| Views | Business logic | Untestable |
| Jobs | Side effects in `perform` | Unpredictable |
| Migrations | Not reversible | Deployment issues |

---

## Models

### Validations

**Check:**
- Presence validation on required fields
- Uniqueness validation (with scope if needed)
- Format validation for emails, URLs, etc.
- Custom validators when built-in insufficient

**Red Flags:**
```ruby
# Bad: No validation
class User < ApplicationRecord
end

# Good: Appropriate validations
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, if: :password_required?
end
```

### Associations

**Check:**
- `inverse_of` defined for frequently used associations
- `dependent` specified to prevent orphaned records
- `class_name` when class name doesn't match convention
- `foreign_key` when column doesn't match convention

**Red Flags:**
```ruby
# Bad: Missing inverse_of (causes extra queries)
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'
end

class User < ApplicationRecord
  has_many :posts
end

# Good: inverse_of specified
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User', inverse_of: :posts
end

class User < ApplicationRecord
  has_many :posts, inverse_of: :author
end
```

### N+1 Queries

**Check:**
- Use `includes` for associations accessed in loops
- Use `select` when only specific columns needed
- Use `joins` when you need filtering but not loading

**Red Flags:**
```ruby
# Bad: N+1
@posts.each { |p| puts p.author.name }

# Good: Eager loading
@posts.includes(:author).each { |p| puts p.author.name }

# Also good: counter_cache
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end
```

### Scopes

**Check:**
- Scopes are chainable
- Default scope avoided or documented
- Scope complexity kept manageable

**Red Flags:**
```ruby
# Bad: Default scope (隐式行为)
class User < ApplicationRecord
  default_scope { where(active: true) }
end

# Good: Named scope with clear name
class User < ApplicationRecord
  scope :active, -> { where(active: true) }
end
```

### Callbacks

**Check:**
- Callback ordering correct
- Callbacks don't have side effects beyond the model
- `transaction` used when callbacks need atomicity

**Red Flags:**
```ruby
# Bad: Callbacks with side effects
class Order < ApplicationRecord
  after_create :send_email, :update_inventory, :notify_slack
end

# Good: Extract to service
class Order < ApplicationRecord
  after_create -> { OrderCreationWorkflow.new(self).call }
end
```

---

## Controllers

### Filters (before_action)

**Check:**
- `before_action` for authentication
- `before_action` for loading resources
- Only necessary actions in `only:` list
- `skip_before_action` when inheriting behavior

**Red Flags:**
```ruby
# Bad: Auth check in every action
def index
  return head :unauthorized unless current_user
  # ...
end

# Good: Use before_action
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :update, :destroy]
end
```

### Strong Parameters

**Check:**
- Parameters whitelisted with `permit`
- Nested attributes handled appropriately
- Array parameters handled correctly

**Red Flags:**
```ruby
# Bad: No strong parameters
def create
  @post = Post.new(params[:post])  # Security risk!
end

# Good: Strong parameters
def post_params
  params.require(:post).permit(:title, :content, :author_id)
end
```

### Error Handling

**Check:**
- `rescue_from` for application-level exceptions
- Proper HTTP status codes
- Consistent JSON error format

**Red Flags:**
```ruby
# Bad: Inline error handling
def show
  @post = Post.find(params[:id])
rescue ActiveRecord::RecordNotFound
  redirect_to posts_path
end

# Good: Consistent handling
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  
  private
  
  def record_not_found
    render json: { error: 'Resource not found' }, status: :not_found
  end
end
```

### Response Format

**Check:**
- Consistent JSON structure
- Proper use of `render json:`
- Appropriate status codes

---

## Jobs (ActiveJob)

### perform Method

**Check:**
- Single responsibility
- No business logic in job
- Arguments are serializable

**Red Flags:**
```ruby
# Bad: Complex logic in job
class ProcessOrderJob < ApplicationJob
  def perform(order_id)
    order = Order.find(order_id)
    order.update!(status: 'processing')
    Inventory.reserve(order.items)
    Payment.charge(order)
    OrderMailer.confirmation(order).deliver_later
    Slack.notify(order)
    # Too much!
  end
end

# Good: Delegate to service object
class ProcessOrderJob < ApplicationJob
  def perform(order_id)
    OrderProcessingService.new(order_id).call
  end
end
```

### Retries and Error Handling

**Check:**
- `retry_on` with exponential backoff
- `discard_on` for non-retryable errors
- Dead letter queue handling

**Red Flags:**
```ruby
# Bad: No retry strategy
class SendEmailJob < ApplicationJob
  def perform(email_id)
    Email.find(email_id).send!
  end
end

# Good: Retry with backoff
class SendEmailJob < ApplicationJob
  retry_on EmailDeliveryError, wait: :exponential_backoff, attempts: 5
  
  def perform(email_id)
    Email.find(email_id).send!
  end
end
```

---

## Mailers

### Delivery

**Check:**
- Use `deliver_later` for async
- Use `deliver_now` when sync required
- Template structure (HTML + plain text)

### Red Flags
```ruby
# Bad: Synchronous delivery
def create
  @user = User.create!(user_params)
  UserMailer.welcome(@user).deliver_now  # Blocks response
end

# Good: Async delivery
def create
  @user = User.create!(user_params)
  UserMailer.welcome(@user).deliver_later
end
```

---

## Migrations

### Zero-Downtime Patterns

**Check:**
- Adding columns with defaults
- Adding NOT NULL constraints with backfill
- Avoiding destructive operations

**Red Flags:**
```ruby
# Bad: Removing column without backup
class RemoveDeprecatedColumn < ActiveRecord::Migration[7.0]
  def up
    remove_column :users, :deprecated_field
  end
end

# Good: Multi-step migration
# Step 1: Add new column
# Step 2: Backfill data
# Step 3: Add constraints
# Step 4: Remove old column (in separate deploy)
```

### Reversibility

**Check:**
- `change` is reversible when possible
- `up`/`down` methods for complex changes
- `reversible` for data migrations

---

## Views

### XSS Prevention

**Check:**
- No `raw` unless absolutely necessary
- No `html_safe` on user input
- Proper escaping by default

**Red Flags:**
```erb
<%= raw @user.bio %>  <!-- Dangerous if bio contains HTML -->

<%= @user.bio %>      <!-- Safe: auto-escaped -->

<%= @user.bio.html_safe %>  <!-- Dangerous if user-provided %>

<%= sanitize @user.bio %>    <!-- Safe: allows limited HTML -->
```

### Helpers

**Check:**
- Logic extracted to helpers when used in views
- View models/decorators for complex presentation
- No database queries in views

---

## Routes

### RESTful Conventions

**Check:**
- Proper REST resources
- Nested routes only when necessary
- Shallow routes for deep nesting

**Red Flags:**
```ruby
# Bad: Non-RESTful
post '/users/:id/activate', to: 'users#activate'

# Good: RESTful with custom action
resource :user, only: [] do
  post :activate, on: :member
end
```

---

## Security Checklist

- [ ] Authentication on all non-public controllers
- [ ] Authorization checks (Pundit/CanCanCan)
- [ ] Strong parameters
- [ ] Mass assignment protection
- [ ] SQL injection prevention (no string interpolation in queries)
- [ ] XSS prevention (no raw/html_safe on user input)
- [ ] CSRF protection (form_with/authenticity_token)
- [ ] Secure cookies (http_only, secure flags)
- [ ] Secrets in environment variables, not in code
- [ ] Rate limiting on sensitive endpoints

---

## Performance Checklist

- [ ] N+1 queries eliminated with includes
- [ ] Counter cache for frequent counts
- [ ] Proper database indexes on queried columns
- [ ] Async jobs for long operations
- [ ] Caching where appropriate (fragment, Russian doll)
- [ ] No N+1 in views (check with bullet gem)
