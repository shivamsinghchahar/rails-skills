# JSON/JSONB Columns

## Storing JSON Data

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.jsonb :metadata, default: {}, null: false
      t.json :raw_data  # JSON (slower)
      t.timestamps
    end
    
    add_index :users, :metadata, using: :gin
  end
end

# JSONB is preferred (binary format, queryable)
# JSON is text format (slower, human-readable)
```

## Accessing JSON Data

```ruby
class User < ApplicationRecord
  store_accessor :metadata, :phone, :address, :preferences
end

# Now access as attributes
user = User.first
user.phone = '555-1234'
user.save

# Or access raw hash
user.metadata['phone'] = '555-1234'
user.metadata = user.metadata.merge(phone: '555-1234')
```

## Querying JSON

```ruby
# Access value
User.where("metadata ->> 'phone' = ?", '555-1234')

# Array contains
User.where("metadata -> 'tags' ? ?", 'vip')

# Contains
User.where("metadata @> ?", { role: 'admin' }.to_json)

# Nested access
User.where("metadata -> 'address' ->> 'city' = ?", 'New York')

# LIKE search
User.where("metadata ->> 'phone' LIKE ?", '555%')

# Has key
User.where("metadata ? ?", 'phone')
```

## JSON Operations

```ruby
# Append to array
user.metadata['tags'] ||= []
user.metadata['tags'] << 'new-tag'

# Merge objects
user.metadata = user.metadata.merge(role: 'admin')

# Delete key
user.metadata.delete('temp_field')

# Type casting in query
User.select("(metadata ->> 'age')::integer as age").where("(metadata ->> 'age')::integer > ?", 18)
```

## Indexing JSON

```ruby
# GIN index for general queries
add_index :users, :metadata, using: :gin

# Expression index for specific key
add_index :users, "(metadata ->> 'email')", unique: true

# Partial index on array membership
add_index :users, :metadata, using: :gin, where: "metadata @> '{\"active\": true}'"
```

## Validation

```ruby
class User < ApplicationRecord
  validates :metadata, presence: true
  
  validate :metadata_valid
  
  private
  
  def metadata_valid
    if metadata.is_a?(Hash) && metadata['email'].present?
      unless /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i.match?(metadata['email'])
        errors.add(:metadata, 'email is invalid')
      end
    end
  end
end
```
