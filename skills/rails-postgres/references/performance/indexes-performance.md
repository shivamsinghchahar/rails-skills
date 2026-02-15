# Indexes and Performance

## Index Types

```ruby
# Single column index
add_index :users, :email

# Compound index
add_index :posts, [:user_id, :created_at]

# Unique index
add_index :users, :email, unique: true

# Partial index (indexed subset)
add_index :posts, :user_id, where: 'published = true'

# GIN index for arrays/JSONB
add_index :users, :metadata, using: :gin

# BTREE (default)
add_index :posts, :created_at, using: :btree

# HASH index
add_index :users, :username, using: :hash
```

## EXPLAIN

View query execution plan:

```ruby
Post.where(published: true).explain
# Output:
# QUERY PLAN
# Seq Scan on posts  (cost=0.00..35.50 rows=100 width=32)
#   Filter: (published = true)

# Analyze running query
Post.where(published: true).explain(:analyze)
```

## Index Analysis

```ruby
# Check indexes on table
ActiveRecord::Base.connection.indexes(:posts)

# List unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;

# Missing indexes (indexes that would help)
SELECT * FROM pg_stat_user_tables
WHERE seq_scan > idx_scan;
```

## Common Performance Issues

### N+1 Queries

```ruby
# Bad: N+1
posts = Post.all
posts.each { |post| post.user.name }  # Queries user for each post

# Good: Eager load
posts = Post.includes(:user)
posts.each { |post| post.user.name }  # Single query for users

# Good: Joins (when you only need user data)
posts = Post.joins(:user).select('posts.*, users.name')
```

### Large Offset

```ruby
# Bad: Slow with large offset
Post.limit(20).offset(10000)

# Good: Use keyset pagination
Post.where('id > ?', last_id).limit(20)
```

### Missing Indexes

Always index columns used in:
- WHERE clauses: `where(user_id: 1)`
- ORDER clauses: `order(created_at: :desc)`
- JOIN conditions: Foreign keys

```ruby
# Good indexes
add_index :posts, :user_id
add_index :posts, :created_at
add_index :comments, [:post_id, :user_id]
```

## Query Optimization

### Pluck Instead of Map

```ruby
# Slow: Load all records
User.all.map(&:email)

# Fast: Only get emails
User.pluck(:email)
```

### Select Specific Columns

```ruby
# Bad: Load all columns
User.all

# Good: Only needed columns
User.select(:id, :name)
```

### Batch Processing

```ruby
# Bad: Load all in memory
User.all.each { |u| u.update(status: 'active') }

# Good: Batch
User.find_each(batch_size: 1000) { |u| u.update(status: 'active') }

# Better: Bulk update
User.update_all(status: 'active')
```
