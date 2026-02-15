# SQL Patterns in Rails

## WHERE Clauses

```ruby
# Simple
User.where(active: true)

# Multiple conditions (AND)
User.where(active: true, role: 'admin')

# OR
User.where('role = ? OR active = ?', 'admin', true)

# IN
User.where(id: [1, 2, 3])

# BETWEEN
User.where(age: 18..65)

# NOT
User.where.not(role: 'admin')

# LIKE
User.where('email LIKE ?', '%@example.com')

# ILIKE (case-insensitive)
User.where('email ILIKE ?', '%JOHN%')
```

## ORDER and GROUP

```ruby
# Order ascending
User.order(:name)
User.order(name: :asc)

# Order descending
User.order(created_at: :desc)

# Multiple order
User.order(status: :asc, created_at: :desc)

# Group with count
Post.group(:user_id).count
# Returns: { 1 => 5, 2 => 3 }

# Group with sum
User.select('users.*, SUM(posts.views) as total_views')
  .joins(:posts).group(:id)

# Having clause
Post.group(:user_id).having('COUNT(*) > ?', 5)
```

## Joins

```ruby
# Inner join (default)
Post.joins(:user)

# Multiple joins
Comment.joins(post: :user)

# Left outer join
Post.left_joins(:user)

# String SQL join
Post.joins('INNER JOIN users ON users.id = posts.user_id')

# Includes (eager load, uses separate query)
Post.includes(:user)

# References (for joins in where clause)
Post.where('users.active = ?', true).references(:user).joins(:user)
```

## Aggregates

```ruby
# Count
Post.count
Post.where(published: true).count

# Sum
Post.sum(:views_count)

# Average
User.average(:age)

# Min/Max
Post.minimum(:created_at)
Post.maximum(:views_count)

# Pluck (single column)
User.pluck(:email)
# Returns array of emails

# Pick (first record values)
User.pick(:name)  # First name value
User.pick(:name, :email)  # [name, email]
```

## Subqueries

```ruby
# Subquery in WHERE
active_posts = Post.where(published: true).select(:id)
comments = Comment.where(post_id: active_posts)

# Exists
Comment.where(<<-SQL
  EXISTS (
    SELECT 1 FROM posts
    WHERE posts.id = comments.post_id
    AND posts.published = true
  )
SQL
)

# IN with subquery
User.where(id: User.where(role: 'admin').select(:id))
```

## Raw SQL

```ruby
# Find by SQL
User.find_by_sql('SELECT * FROM users WHERE active = true LIMIT 1')

# Execute SQL
result = ActiveRecord::Base.connection.execute(
  'SELECT COUNT(*) FROM users WHERE active = true'
)

# Using sanitize
User.where(User.sanitize_sql_for_conditions(
  ['role = ? AND active = ?', 'admin', true]
))
```
