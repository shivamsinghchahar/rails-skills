# Advanced Query Patterns

## Complex WHERE Clauses

```ruby
# Multiple conditions
Post.where(published: true)
  .where('created_at > ?', 1.month.ago)
  .where('views_count > ?', 100)

# OR with AND
Post.where('published = ? AND (views_count > ? OR featured = ?)', 
          true, 1000, true)

# BETWEEN date range
Post.where(created_at: 1.month.ago..Time.current)

# Array contains (JSONB)
User.where("metadata -> 'tags' ? ?", 'rails')

# String search
User.where('email ILIKE ?', "%#{search_term}%")
```

## Aggregations

```ruby
# Posts per user
Post.group(:user_id).count
# Returns: { 1 => 5, 2 => 3, 3 => 8 }

# Total views by user
User.select('users.id, users.name, SUM(posts.views_count) as total_views')
  .joins(:posts)
  .group('users.id, users.name')
  .order('total_views DESC')

# Average post length by category
Post.group(:category)
  .select('category, AVG(LENGTH(content)) as avg_length')
  .order('avg_length DESC')

# Count with having
Post.group(:user_id)
  .having('COUNT(*) > ?', 5)
  .count

# Multiple aggregates
Post.group(:user_id).select(
  'user_id, 
   COUNT(*) as post_count, 
   AVG(views_count) as avg_views,
   SUM(views_count) as total_views'
)
```

## Date Queries

```ruby
# Posts from this month
Post.where('created_at >= ? AND created_at < ?',
  Date.today.beginning_of_month,
  Date.today.end_of_month)

# Or simpler
Post.where(created_at: Date.today.all_month)

# Last 7 days
Post.where('created_at > ?', 7.days.ago)

# Per day grouping
Post.group("DATE(created_at)").count
# Returns: { 2024-01-01 => 5, 2024-01-02 => 3 }

# Date truncation
Post.select("DATE_TRUNC('month', created_at) as month, COUNT(*)")
  .group("DATE_TRUNC('month', created_at)")
```

## Full-Text Search

```ruby
# Simple text search
Post.where('content @@ ?', 'ruby')

# Weighted search
Post.select('posts.*, ts_rank(to_tsvector(content), query) as rank')
  .joins("CROSS JOIN to_tsquery(?) as query", 'ruby')
  .where('to_tsvector(content) @@ query')
  .order('rank DESC')

# Using PostgreSQL trigram for fuzzy search
Post.where('title % ?', 'railes')  # Matches "rails"
```

## Distinct and Unique

```ruby
# Distinct values
Post.distinct.pluck(:user_id)

# Distinct on multiple columns
Post.select('DISTINCT ON (user_id) *')
  .order('user_id, created_at DESC')

# Count distinct
User.distinct.count(:email)
```

## Window Functions

```ruby
# Row number
Post.select('
  *,
  ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) as row_num
').where('row_num = 1')

# Running total
Post.select('
  *,
  SUM(views_count) OVER (
    PARTITION BY user_id 
    ORDER BY created_at 
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) as running_total
')
```

## JSON/JSONB Queries

```ruby
# Contains
User.where("metadata @> ?", { role: 'admin' }.to_json)

# Access key
User.where("metadata ->> 'department' = ?", 'engineering')

# Array contains
User.where("metadata -> 'tags' ? ?", 'vip')

# JSONB has key
User.where("metadata ? ?", 'social_links')

# Array length
User.where("jsonb_array_length(metadata -> 'tags') > ?", 5)
```

## Set Operations

```ruby
# UNION
admin_users = User.where(role: 'admin').select(:id)
moderator_users = User.where(role: 'moderator').select(:id)
union_query = admin_users.union(moderator_users)

# INTERSECT
Post.where(published: true).select(:id)
  .intersect(Post.where(featured: true).select(:id))

# EXCEPT
Post.where(published: true).select(:id)
  .except(Post.where(flagged: true).select(:id))
```
