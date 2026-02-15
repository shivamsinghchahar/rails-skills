# Enums and Custom Types

## Enum Columns (String-based)

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.string :status, default: 'draft'
      t.timestamps
    end
  end
end

# Model
class Post < ApplicationRecord
  enum status: { draft: 'draft', published: 'published', archived: 'archived' }
  validates :status, presence: true
end
```

## Using Enums

```ruby
post = Post.new
post.status = 'draft'
post.draft?              # true
post.published?          # false
post.draft!              # Save with status=draft

# Query
Post.draft               # All draft posts
Post.where(status: :published)

# Scopes
scope :published, -> { where(status: 'published') }

# Callbacks
before_save :validate_transitions

def validate_transitions
  # Prevent invalid state changes
end
```

## PostgreSQL Native Enums

```ruby
class CreateEnumStatus < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      CREATE TYPE post_status AS ENUM ('draft', 'published', 'archived');
    SQL
  end
  
  def down
    execute 'DROP TYPE post_status'
  end
end

class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.column :status, :post_status, default: 'draft'
      t.timestamps
    end
  end
end
```

## Custom Type Classes

```ruby
# Custom type for phone numbers
class PhoneType < ActiveRecord::Type::String
  def cast(value)
    return value if value.is_a?(PhoneNumber)
    return nil if value.nil?
    
    PhoneNumber.parse(value)
  end
  
  def serialize(value)
    value&.to_s
  end
end

# Register type
ActiveRecord::Type.register(:phone, PhoneType)

# Use in migration
t.column :phone, :phone

# Model handles type casting automatically
user.phone = '555-1234'
user.phone.formatted  # Automatically uses PhoneType
```

## Value Objects

```ruby
class Money
  def initialize(amount, currency = 'USD')
    @amount = amount
    @currency = currency
  end
  
  def ==(other)
    amount == other.amount && currency == other.currency
  end
end

# Store as JSON
class Order < ApplicationRecord
  store :price_data, accessors: [:amount, :currency]
  
  def price
    Money.new(price_data['amount'], price_data['currency'])
  end
end
```

## Attribute Aliases

```ruby
class User < ApplicationRecord
  alias_attribute :full_name, :name
end

user.full_name = 'John Doe'
user.name      # 'John Doe'
```

## Type Casting

```ruby
class User < ApplicationRecord
  attribute :age, :integer
  attribute :active, :boolean
  attribute :tags, :string, array: true
  attribute :metadata, :jsonb
  
  # Custom attribute type
  attribute :phone, PhoneType.new
end

user = User.new
user.age = '25'
user.age.class          # Integer
user.age                # 25
```
