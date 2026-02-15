# Query Optimization

## N+1 Query Detection

Use bullet gem to detect N+1 queries:

```ruby
# Gemfile
gem 'bullet', group: :development

# config/initializers/bullet.rb
if defined?(Bullet)
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.raise = true  # Raise exceptions in development
end
```

## Eager Loading Strategies

```ruby
# includes: Separate queries for associations
Post.includes(:user, :comments)

# joins: Single query with joins
Post.joins(:user).where(users: { active: true })

# eager_load: Force single query with outer join
Post.eager_load(:user)

# preload: Explicit separate query
Post.preload(:user)

# distinct: Remove duplicates from joins
Post.joins(:comments).distinct
```

## Measuring Query Performance

```ruby
# Time a query
@posts = Post.all
Post.connection.queries.last  # See last query

# Use Rails logger
Post.logger = Logger.new(STDOUT)
Post.where(published: true)  # Logs the query

# Benchmark code
Benchmark.bm do |x|
  x.report("With includes") { Post.includes(:user).to_a }
  x.report("With join") { Post.joins(:user).to_a }
end
```

## Query Plan Analysis

```ruby
# Check if using index
explain = Post.where(user_id: 1).explain(:analyze)

# Look for:
# - "Index Scan" = using index (good)
# - "Seq Scan" = full table scan (bad for large tables)
# - "cost=X..Y" = estimated cost

# If cost is high, add index:
add_index :posts, :user_id
```

## Pagination

```ruby
# Offset-based (slow with large offsets)
Post.page(params[:page]).per(20)

# Keyset-based (fast for large datasets)
Post.where('id > ?', params[:last_id]).limit(20)

# Or use gems
# gem 'kaminari' or 'will_paginate'
```

## Caching Results

```ruby
# Cache expensive query
cached_count = Rails.cache.fetch('active_users_count', expires_in: 1.hour) do
  User.where(active: true).count
end

# Cache associations
class User < ApplicationRecord
  has_many :posts
  
  def recent_posts
    Rails.cache.fetch("user_#{id}_recent_posts", expires_in: 30.minutes) do
      posts.recent.limit(5)
    end
  end
end
```

## Database Connection Pooling

```ruby
# config/database.yml
development:
  adapter: postgresql
  pool: 5        # Connection pool size
  timeout: 5000  # Timeout in ms
```

## Avoid Common Pitfalls

```ruby
# Bad: Multiple queries for conditional operations
user.save if user.valid?

# Good: Save handles validation
user.save

# Bad: Calling count on large result set
Post.all.count  # Loads all then counts

# Good: Count at database level
Post.count      # SQL COUNT

# Bad: Checking size on association
user.posts.size  # Loads association

# Good: Count at database level
user.posts.count
```
