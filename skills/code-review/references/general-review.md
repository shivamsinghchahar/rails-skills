# General Review Principles

Universal principles that apply to all codebases regardless of language or framework.

## The Seven Things Reviewers Look For

Based on Google's code review best practices, every review should evaluate:

1. **Design** - Is the code well-designed?
2. **Functionality** - Does it behave as intended?
3. **Complexity** - Could it be simpler?
4. **Tests** - Are they correct and well-designed?
5. **Naming** - Are names clear and descriptive?
6. **Comments** - Are comments clear and useful?
7. **Style** - Does it follow style guides?

---

## 1. Design

### Questions to Ask
- Is this code in the right place?
- Is there proper separation of concerns?
- Are dependencies pointing in the right direction?
- Would another developer know where to find this functionality?

### Patterns to Check
- **Single Responsibility**: Each class/method does one thing well
- **Open/Closed**: Open for extension, closed for modification
- **Dependency Injection**: Depend on abstractions, not concretions
- **Law of Demeter**: Talk to immediate friends, not strangers

### Red Flags
```
✗ God classes/modules doing too much
✗ Circular dependencies
✗ Feature envy (one class overly interested in another's data)
✗ Shotgun surgery (one change requires many scattered edits)
```

### Good Example (Rails)
```ruby
# Good: Proper separation
# app/services/user_creator.rb
class UserCreator
  def initialize(user_params)
    @user_params = user_params
  end

  def call
    user = User.new(user_params)
    user.skip_confirmation!
    user.save!
    UserMailer.welcome(user).deliver_later
    user
  end
end

# app/controllers/users_controller.rb
def create
  @user = UserCreator.new(user_params).call
  redirect_to @user, notice: 'Welcome!'
end
```

---

## 2. Functionality

### Questions to Ask
- Does this code do what the PR description says?
- Is this good for users, not just for the author?
- Edge cases handled?
- Error cases handled?

### Patterns to Check
- **Happy path**: Normal usage works
- **Edge cases**: Empty inputs, null values, boundary conditions
- **Error handling**: Graceful failures, not silent crashes
- **Boundary conditions**: Off-by-one, max values, time zones

### Red Flags
```
✗ Missing null/nil checks
✗ No handling of empty collections
✗ Assumptions about input format
✗ Silent failures or swallowed exceptions
```

### Good Example
```ruby
# Good: Handles edge cases
def calculate_discount(order)
  return 0 unless order
  return 0 unless order.total_cents > 0
  return 0 if order.coupon_code.nil?
  
  coupon = Coupon.find_by(code: order.coupon_code)
  return 0 unless coupon&.active?
  
  coupon.discount_percent / 100.0 * order.total_cents
end
```

---

## 3. Complexity

### Questions to Ask
- Could a new developer understand this easily?
- Is this the simplest solution that works?
- Would this be easier to understand with extraction?
- Are there levels of nesting beyond 2-3?

### Red Flags
```
✗ Methods over 50 lines
✗ Classes over 200 lines
✗ Nesting beyond 3 levels
✗ Boolean logic that's hard to follow
✗ Clever code that sacrifices readability
```

### Good Example
```ruby
# Good: Flat structure with early returns
def process_order(order)
  return failure(:invalid_order) unless order.valid?
  return failure(:already_processed) if order.processed?
  return failure(:out_of_stock) unless inventory.available?(order)
  
  inventory.reserve(order)
  order.mark_processed!
  payment.capture(order)
  
  success(order)
end
```

---

## 4. Tests

### Questions to Ask
- Are there tests?
- Do they test behavior, not implementation?
- Are edge cases covered?
- Are tests deterministic?

### Patterns to Check
- **Test behavior, not internals**: Test what the code does, not how
- **Arrange-Act-Assert**: Clear test structure
- **Descriptive names**: `test_user_creation_with_valid_data_succeeds`
- **No test interdependencies**: Each test runs independently
- **Proper setup/teardown**: Clean state between tests

### Red Flags
```
✗ Tests with no assertions
✗ Testing implementation details
✗ Shared mutable state between tests
✗ Tests that only pass in specific order
✗ Magic numbers in tests without explanation
```

### Good Example
```ruby
RSpec.describe OrderCreator do
  describe '#call' do
    context 'with valid params' do
      let(:params) { { user_id: user.id, product_ids: [product.id] } }
      
      it 'creates an order' do
        expect { creator.call }.to change(Order, :count).by(1)
      end
      
      it 'sends confirmation email' do
        expect { creator.call }.to have_enqueued_mail(OrderMailer, :confirmation)
      end
    end
    
    context 'with invalid user' do
      let(:params) { { user_id: nil, product_ids: [product.id] } }
      
      it 'returns failure result' do
        expect(creator.call).to be_failure
      end
    end
  end
end
```

---

## 5. Naming

### Questions to Ask
- Does the name describe what it is or does?
- Would a new developer understand it?
- Are abbreviations avoided unless widely known?
- Is casing consistent?

### Principles
| Type | Convention | Example |
|------|------------|---------|
| Variables | snake_case | `user_count` |
| Methods | snake_case | `find_by_email` |
| Classes | PascalCase | `UserCreator` |
| Constants | SCREAMING_SNAKE | `MAX_RETRIES` |
| Boolean vars | is_/has_/should_ | `is_active`, `has_permission` |

### Red Flags
```
✗ Single letters (except simple loops: i, j, k)
✗ Abbreviations not widely known (u instead of user)
✗ Generic names (data, info, temp, tmp)
✗ Inconsistent naming within same codebase
```

---

## 6. Comments

### Questions to Ask
- Does this comment explain *why*, not *what*?
- Is the comment still accurate?
- Are complex algorithms explained?
- Are edge cases documented?

### Principles
```ruby
# Good: Explains WHY
# We use SECONDS_PER_DAY instead of 86400 because this code
# will be read by developers who may not know seconds in a day.
SECONDS_PER_DAY = 86400

# Bad: Explains WHAT (code already does this)
# Increment counter by 1
counter += 1

# Good: Explains complex logic
# Using BFS instead of DFS because we need shortest path
# and the graph can be very deep (recursion risk)
def shortest_path(start, goal)
```

### Red Flags
```
✗ Commented-out code
✗ Obvious comments restating the code
✗ TODO without ticket reference
✗ Outdated comments
✗ Empty comments (just for structure)
```

---

## 7. Style

### Questions to Ask
- Does this follow the project's style guide?
- Is formatting consistent?
- Are there automated style checks?

### Common Conventions
- **Ruby**: RuboCop with StandardRB or custom config
- **JavaScript/TypeScript**: ESLint + Prettier
- **Python**: PEP 8, Black

### Red Flags
```
✗ Ignoring linter warnings
✗ Inconsistent formatting
✗ Mixing styles within file
```

---

## General Anti-Patterns

### Duplicate Code
```ruby
# Bad: Duplication
def send_invoice
  invoice = Invoice.create!(user: user, amount: amount)
  Mailer.deliver(invoice)
end

def send_receipt
  receipt = Receipt.create!(user: user, amount: amount)
  Mailer.deliver(receipt)
end

# Good: Extract common behavior
def send_document(user, type, amount)
  document = "#{type.classify}ing".safe_constantize.create!(user: user, amount: amount)
  Mailer.deliver(document)
end
```

### Dead Code
```ruby
# Bad: Unused code
def old_method
  # This method is no longer called
end

# Good: Remove or comment WHY it's kept
# Kept for backward compatibility with v1 API
# TODO: Remove in v2.0
def deprecated_method
end
```

### Magic Numbers
```ruby
# Bad
sleep 86400 * 7  # What?

# Good
SUBSCRIPTION_GRACE_PERIOD = 7.days
sleep SUBSCRIPTION_GRACE_PERIOD
```
