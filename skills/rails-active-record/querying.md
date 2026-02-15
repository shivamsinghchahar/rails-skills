# Querying

Active Record provides a rich API for constructing SQL queries in a Ruby-friendly way, with chainable methods for filtering, ordering, limiting, and retrieving data.

## Basic Queries

### Finding Records

```ruby
# Find by primary key
user = User.find(1)

# Find multiple records
users = User.find(1, 2, 3)

# Find by attribute
user = User.find_by(email: "user@example.com")

# Find or raise error
user = User.find_by!(email: "user@example.com")  # Raises ActiveRecord::RecordNotFound

# Find all
all_users = User.all
```

## WHERE Conditions

Filter records using `where` with various syntaxes.

### Simple Conditions

```ruby
# Hash-based conditions (safe from SQL injection)
active_users = User.where(active: true)
posts_by_user = Post.where(user_id: 1)

# Multiple conditions (AND)
User.where(active: true, role: 'admin')
```

### String-Based Conditions (with Placeholders)

```ruby
# Using placeholders for values (safer than string interpolation)
User.where("created_at > ?", 1.week.ago)
User.where("age >= ? AND active = ?", 18, true)

# Named placeholders
User.where("created_at > :date AND active = :active", { date: 1.week.ago, active: true })
```

### Complex Conditions with AND/OR

```ruby
# AND
User.where(active: true).where(role: 'admin')

# OR with multiple values
User.where(status: ['pending', 'active'])

# Complex AND/OR combinations
User.where("(active = true AND role = 'admin') OR (created_at > ?)", 1.month.ago)

# Using OR chains (Rails 7.0+)
User.where(role: 'admin').or(User.where(role: 'moderator'))
```

### IN and NOT Conditions

```ruby
# IN
Post.where(status: ['draft', 'published'])

# NOT IN
Post.where.not(status: 'archived')

# NOT NULL
User.where.not(deleted_at: nil)
```

## Scopes

Scopes are named queries that return an ActiveRecord::Relation and can be chained.

### Class-Level Scopes

```ruby
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user_id: user.id) }
  scope :this_month, -> { where("created_at > ?", 1.month.ago) }
  scope :active_with_comments, -> { where.not(comments_count: 0) }
end

# Usage
Post.published  # All published posts
Post.published.recent  # Published posts, most recent first
Post.by_user(current_user)  # Posts by specific user
Post.published.recent.by_user(current_user)  # Chainable
```

### Scope with Conditions

```ruby
class User < ApplicationRecord
  scope :by_role, ->(role) { where(role: role) if role.present? }
  
  scope :created_after, ->(date) do
    where("created_at > ?", date) if date.present?
  end
end

# Safe even if parameters are nil
User.by_role(params[:role]).created_after(params[:start_date])
```

### Class Methods vs Scopes

```ruby
class Post < ApplicationRecord
  # Scope (returns Relation, always chainable)
  scope :published, -> { where(published: true) }
  
  # Class method (more flexible but less consistent)
  def self.recent(limit = 10)
    order(created_at: :desc).limit(limit)
  end
end

# Scopes are preferred because they return Relation
Post.published.recent(5)
```

## Eager Loading

Prevent N+1 queries by loading associated records in advance.

### includes (for associations)

`includes` loads associated records in separate queries, preventing N+1 problems.

```ruby
# Without eager loading (N+1 problem - 11 queries)
@users = User.limit(10)
@users.each do |user|
  puts user.posts.count  # 1 query per user
end

# With eager loading (2 queries)
@users = User.includes(:posts).limit(10)
@users.each do |user|
  puts user.posts.count  # Posts already loaded, no new queries
end

# Multiple associations
posts = Post.includes(:user, :comments)

# Nested associations
users = User.includes(posts: :comments)
```

### joins (for filtering)

`joins` filters records based on associated data using SQL INNER JOIN.

```ruby
# Get users who have posts
users_with_posts = User.joins(:posts)

# Get users with published posts
users_with_published = User.joins(:posts).where(posts: { published: true })

# Count distinct users
User.joins(:posts).distinct.count

# Multiple joins
Post.joins(:user, :comments)
```

### left_outer_joins (for optional associations)

```ruby
# Get all users, including those without posts
users = User.left_outer_joins(:posts)

# Get users without posts
users_without_posts = User.left_outer_joins(:posts).where(posts: { id: nil })
```

## N+1 Query Prevention

### Identifying N+1 Queries

```ruby
# BAD: N+1 query
@posts = Post.all
@posts.each do |post|
  puts post.user.name  # 1 + number of posts queries
end

# GOOD: Eager load
@posts = Post.includes(:user)
@posts.each do |post|
  puts post.user.name  # Uses already-loaded user
end
```

### Strategic Eager Loading

```ruby
class PostsController < ApplicationController
  def index
    # Eager load what you know you'll need
    @posts = Post.includes(:user, :comments).limit(20)
  end
  
  def show
    @post = Post.includes(comments: :user).find(params[:id])
  end
end
```

## Ordering

Retrieve records in a specific order.

```ruby
# Sort ascending
User.order(created_at: :asc)
User.order(:name)  # Ascending is default

# Sort descending
User.order(created_at: :desc)

# Multiple columns
Post.order(published_at: :desc, created_at: :desc)

# Using raw SQL
User.order("RANDOM()")  # For PostgreSQL
User.order("RAND()")    # For MySQL
```

## Limiting and Offsetting

Control the number and position of returned records.

```ruby
# Limit results
User.limit(10)

# Skip results (offset)
User.limit(10).offset(20)  # Skip first 20, get next 10

# Pagination pattern
page = 2
per_page = 20
User.limit(per_page).offset((page - 1) * per_page)
```

## Aggregations

Calculate aggregates across records.

```ruby
# Count
User.count  # Total users
User.where(active: true).count  # Active users

# Sum
Product.sum(:price)  # Total value
Post.where(published: true).sum(:views)

# Average
Product.average(:price)

# Min/Max
Product.minimum(:price)
Product.maximum(:price)

# Group with aggregation
Order.group(:user_id).count
# => {1 => 5, 2 => 3}  # user_id => order count

Post.group(:status).sum(:views)
# => {"draft" => 100, "published" => 5000}
```

## DISTINCT Queries

Return unique values to prevent duplicates.

```ruby
# Get distinct user IDs from posts
Post.distinct.pluck(:user_id)

# Distinct with association
User.joins(:posts).distinct
```

## Select Specific Columns

Retrieve only needed columns for performance.

```ruby
# Select specific columns
User.select(:id, :name, :email)

# Alias columns
User.select("id, name, email AS user_email")

# Select from SQL query
User.select("*, (SELECT count(*) FROM posts WHERE posts.user_id = users.id) as posts_count")
```

## Complex Query Examples

### Combining Multiple Conditions

```ruby
class Post < ApplicationRecord
  scope :published_recently, -> {
    where(published: true)
      .where("published_at > ?", 1.week.ago)
      .order(published_at: :desc)
  }
  
  scope :popular, -> {
    where("views > ?", 1000)
  }
  
  scope :with_engagement, -> {
    where("comments_count > 0 OR likes_count > 0")
  }
end

# Usage
Post.published_recently.popular.with_engagement
```

### Querying Associations

```ruby
# Posts by a specific user with comments
Post.where(user_id: 1).where("comments_count > 0")

# Comments on posts by admin users
Comment.joins(post: :user).where(users: { role: 'admin' })

# Recent posts with their comment count
Post.select("posts.*, COUNT(comments.id) as comment_count")
  .joins(:comments)
  .where("posts.created_at > ?", 1.month.ago)
  .group("posts.id")
```

## Best Practices

- **Always eager load associated records**: Use `includes` to prevent N+1 queries
- **Use scopes for reusable queries**: Makes code more readable and maintainable
- **Prefer `where.not` over NOT conditions**: Clearer intent
- **Use placeholders in SQL**: Prevent SQL injection vulnerabilities
- **Test query performance**: Use `explain` to understand query plans
- **Limit result sets**: Use `limit` and `offset` for large datasets
- **Index frequently queried columns**: Work with your database team
- **Avoid queries in loops**: Always eager load first
