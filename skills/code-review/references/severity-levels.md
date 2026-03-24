# Severity Levels

Classification system for code review findings with corresponding action required.

## Overview

Every finding should be classified into one of four severity levels:

| Level | Name | Color | Description |
|-------|------|-------|-------------|
| **P0** | Critical | 🔴 | Must block merge |
| **P1** | High | 🟠 | Should fix before merge |
| **P2** | Medium | 🟡 | Fix in PR or follow-up |
| **P3** | Low | 🟢 | Optional improvement |

---

## P0 - Critical

### Definition
Issues that introduce security vulnerabilities, risk data loss, or cause correctness bugs.

### Characteristics
- Exploitable security flaw (SQL injection, XSS, auth bypass)
- Data corruption or loss possible
- Application crashes in production
- Breaks fundamental functionality
- Race conditions causing data inconsistency

### Examples

**SQL Injection:**
```ruby
# Critical: User input directly in SQL query
User.where("name = '#{params[:name]}'")

# P0 Fix: Parameterized query
User.where("name = ?", params[:name])
```

**Missing authentication on sensitive endpoint:**
```ruby
# Critical: No auth check
def update
  @user.update!(user_params)
end

# P0 Fix: Add authentication
before_action :authenticate_user!
before_action :set_user, only: [:update]
```

**React: XSS vulnerability:**
```tsx
// Critical: Raw HTML injection
return <div dangerouslySetInnerHTML={{__html: userInput}} />

// P0 Fix: Sanitize or use textContent
return <div>{userInput}</div>
```

### Required Action
**Must block merge.** Do not ship until resolved.

---

## P1 - High

### Definition
Issues that cause logic errors, significant SOLID violations, or performance regressions.

### Characteristics
- Logic error producing wrong results
- Significant code smell affecting maintainability
- Performance issue on hot path
- SOLID principle violation (hard to test, change, understand)
- Missing error handling
- Breaking established patterns

### Examples

**N+1 Query:**
```ruby
# High: N+1 query in loop
@users.each { |u| puts u.posts.count }

# P1 Fix: Eager load associations
@users.includes(:posts).each { |u| puts u.posts.count }
```

**React: Missing dependency in useEffect:**
```tsx
// High: Stale closure bug
useEffect(() => {
  fetchData(id);
}, []); // Missing id dependency

// P1 Fix: Include all dependencies
useEffect(() => {
  fetchData(id);
}, [id]);
```

**Incorrect error handling:**
```ruby
# High: Swallowing exceptions
begin
  processpayment
rescue StandardError
  nil  # Silent failure
end

# P1 Fix: Handle or re-raise with context
begin
  processpayment
rescue PaymentError => e
  Rails.logger.error("Payment failed: #{e.message}")
  raise
end
```

### Required Action
**Should fix before merge.** Address these issues before shipping.

---

## P2 - Medium

### Definition
Code smells, maintainability concerns, or minor SOLID violations.

### Characteristics
- Code is functional but could be cleaner
- Minor duplication that should be extracted
- Inconsistent naming or formatting
- Missing comments on complex logic
- Suboptimal but not wrong algorithm
- Prop drilling beyond 2-3 levels

### Examples

**Magic numbers:**
```ruby
# Medium: Magic number
delay = 86400 * 7

# P2 Fix: Named constant
MAX_SESSION_DURATION = 7.days
delay = MAX_SESSION_DURATION
```

**React: Prop drilling:**
```tsx
// Medium: Props passed through multiple levels
<UserList user={user} onUpdate={onUpdate} />

// P2 Fix: Use composition or context
<UserListProvider user={user}>
  <UserList />
</UserListProvider>
```

**Inconsistent naming:**
```ruby
# Medium: Mixed naming conventions
def get_user_by_id(id)  # camelCase
def find_or_create_user  # snake_case (preferred)
end

# P2 Fix: Use consistent snake_case
def get_user_by_id(id)
def find_or_create_user
end
```

### Required Action
**Fix in this PR or create follow-up issue.** Balance fixing vs. moving fast.

---

## P3 - Low

### Definition
Style preferences, naming suggestions, or minor improvements.

### Characteristics
- Pure style preference
- Naming could be more descriptive
- Minor formatting inconsistency
- Comment could be clearer
- Could use a different idiom
- Unused code/variables

### Examples

**Undescriptive variable name:**
```tsx
// Low: Single letter variable
const d = new Date();

// P3 Fix: Use descriptive name
const currentDate = new Date();
```

**RuboCop style violations:**
```ruby
# Low: Single line method (fine, but not convention)
def email; @email; end

# P3 Fix: Expand to multi-line
def email
  @email
end
```

**Verbose logging:**
```ruby
# Low: Unnecessary interpolation
Rails.logger.info "User #{user.id} created"

# P3 Fix: Direct interpolation
Rails.logger.info "User #{user.id} created"  # actually fine
# Or: Rails.logger.info { "User #{user.id} created" }
```

### Required Action
**Optional improvement.** Address if time permits, otherwise note for later.

---

## Decision Framework

When classifying a finding, ask:

1. **Does this break production?** → P0
2. **Does this cause wrong behavior or security issue?** → P0 or P1
3. **Does this make the code hard to maintain?** → P1 or P2
4. **Is this just a preference?** → P3

When in doubt, **classify higher** (P2 instead of P3). It's easier to downgrade than upgrade during review.
