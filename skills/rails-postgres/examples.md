# PostgreSQL Examples in Rails

Real-world examples combining datatypes, queries, and performance optimization.

## User with Multiple Types

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto'
    
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :roles, array: true, default: ['user']
      t.jsonb :metadata, default: {}, null: false
      t.enum :status, enum_type: :user_status, default: 'active'
      t.daterange :subscription_period
      t.timestamps
    end
    
    add_index :users, :email, unique: true
    add_index :users, :metadata, using: :gin
  end
end

class User < ApplicationRecord
  store_accessor :metadata, :phone, :location, :preferences
  enum status: { active: 'active', inactive: 'inactive', suspended: 'suspended' }
  
  validates :email, presence: true, uniqueness: true
  validates :roles, presence: true
  
  def admin?
    roles.include?('admin')
  end
end
```

## Event with Dates and Times

```ruby
class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :title
      t.text :description
      t.daterange :event_dates
      t.time :start_time
      t.time :end_time
      t.jsonb :location, default: {}
      t.string :categories, array: true, default: []
      t.timestamps
    end
  end
end

class Event < ApplicationRecord
  store_accessor :location, :address, :city, :country, :coordinates
  
  validates :title, presence: true
  validates :event_dates, presence: true
  validate :dates_valid
  
  scope :upcoming, -> { where('event_dates @> ?::daterange', Date.today) }
  
  private
  
  def dates_valid
    if event_dates&.exclude_end?
      errors.add(:event_dates, 'must include start and end dates')
    end
  end
end
```

## Product with Pricing and Variants

```ruby
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name
      t.numrange :price_range
      t.jsonb :variants, default: []
      t.string :tags, array: true
      t.jsonb :seo, default: {}
      t.timestamps
    end
  end
end

class Product < ApplicationRecord
  store_accessor :seo, :title, :description, :keywords
  
  validate :variants_valid
  
  def add_variant(sku:, price:, stock:)
    self.variants ||= []
    self.variants << { sku:, price:, stock: }
  end
  
  def update_price_range
    prices = variants.map { |v| v[:price] }
    self.price_range = prices.min..prices.max
  end
  
  private
  
  def variants_valid
    if variants.is_a?(Array)
      variants.each do |variant|
        unless variant.is_a?(Hash) && variant.key?(:sku)
          errors.add(:variants, 'must have sku')
        end
      end
    end
  end
end
```

## Survey with Complex Metadata

```ruby
class CreateSurveys < ActiveRecord::Migration[7.1]
  def change
    create_table :surveys do |t|
      t.string :title
      t.text :description
      t.jsonb :questions, default: []
      t.string :allowed_roles, array: true, default: ['user']
      t.daterange :active_period
      t.jsonb :settings, default: {}
      t.timestamps
    end
  end
end

class Survey < ApplicationRecord
  store_accessor :settings, :shuffle_questions, :show_progress, :allow_partial
  
  def add_question(type:, text:, options: [])
    self.questions ||= []
    self.questions << {
      id: SecureRandom.uuid,
      type:,
      text:,
      options:,
      created_at: Time.current
    }
  end
  
  def question_count
    (questions || []).length
  end
  
  scope :active_now, -> { 
    where("active_period @> ?::daterange", Date.today.to_date)
  }
end
```

## Query Examples

### Complex WHERE Clauses

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

### Aggregations

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
```

### Date Queries

```ruby
# Posts from this month
Post.where('created_at >= ? AND created_at < ?',
  Date.today.beginning_of_month,
  Date.today.end_of_month)

# Last 7 days
Post.where('created_at > ?', 7.days.ago)

# Per day grouping
Post.group("DATE(created_at)").count
# Returns: { 2024-01-01 => 5, 2024-01-02 => 3 }

# Date truncation
Post.select("DATE_TRUNC('month', created_at) as month, COUNT(*)")
  .group("DATE_TRUNC('month', created_at)")
```

### Full-Text Search

```ruby
# Simple text search
Post.where('content @@ ?', 'ruby')

# Weighted search
Post.select('posts.*, ts_rank(to_tsvector(content), query) as rank')
  .joins("CROSS JOIN to_tsquery(?) as query", 'ruby')
  .where('to_tsvector(content) @@ query')
  .order('rank DESC')

# Fuzzy search (trigram)
Post.where('title % ?', 'railes')  # Matches "rails"
```

### Window Functions

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

## Performance Best Practices

### Eager Loading

```ruby
# Avoid N+1 queries
posts = Post.includes(:user, :comments)  # Separate queries
posts.each { |post| post.user.name }

# Or use joins when you only need data
posts = Post.joins(:user).select('posts.*, users.name')
```

### Pagination

```ruby
# Offset-based (slow with large offsets)
Post.page(params[:page]).per(20)

# Keyset-based (fast for large datasets)
Post.where('id > ?', params[:last_id]).limit(20)
```

### Indexing Strategy

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :content
      t.uuid :user_id
      t.jsonb :metadata, default: {}
      t.string :tags, array: true
      t.boolean :published
      t.timestamps
    end
    
    # Strategic indexes
    add_index :posts, :user_id              # Foreign key
    add_index :posts, :published            # WHERE clause
    add_index :posts, :created_at           # ORDER BY
    add_index :posts, :metadata, using: :gin # JSONB queries
    add_index :posts, :tags, using: :gin    # Array queries
    add_index :posts, [:user_id, :published] # Combined filter
  end
end
```

### Batch Processing

```ruby
# Bad: Load all in memory
User.all.each { |u| u.update(status: 'active') }

# Good: Batch process
User.find_each(batch_size: 1000) { |u| u.update(status: 'active') }

# Better: Bulk update
User.update_all(status: 'active')
```

### Caching Expensive Queries

```ruby
# Cache results
cached = Rails.cache.fetch('active_users_count', expires_in: 1.hour) do
  User.where(status: 'active').count
end

# Invalidate when needed
Rails.cache.delete('active_users_count')
```
