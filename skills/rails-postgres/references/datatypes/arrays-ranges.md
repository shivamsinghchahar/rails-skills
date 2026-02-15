# Arrays and Ranges

## Array Columns

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :roles, array: true, default: []
      t.integer :favorite_numbers, array: true
      t.timestamps
    end
    
    add_index :users, :roles, using: :gin
  end
end

# Model
class User < ApplicationRecord
  validates :roles, presence: true
end
```

## Array Operations

```ruby
user = User.first

# Append
user.roles << 'admin'
user.roles.push('moderator')

# Remove
user.roles.delete('admin')
user.roles -= ['moderator']

# Combine
user.roles = (user.roles + ['editor']).uniq

# Replace
user.update(roles: ['user', 'admin'])

# Save
user.save
```

## Querying Arrays

```ruby
# Contains element
User.where("roles ? ?", 'admin')

# Array contains all
User.where("roles @> ARRAY[?, ?]::varchar[]", 'admin', 'user')

# Array overlaps (has any)
User.where("roles && ARRAY[?, ?]::varchar[]", 'admin', 'moderator')

# Array length
User.where("array_length(roles, 1) > ?", 2)

# Get element by index
User.select("roles[1] as first_role")
```

## Range Columns

```ruby
class CreateRatings < ActiveRecord::Migration[7.1]
  def change
    create_table :ratings do |t|
      t.integer :int_range, default: '0'::range
      t.daterange :availability
      t.numrange :price_range
      t.timestamps
    end
  end
end
```

## Range Operations

```ruby
# Create range
date_range = Date.new(2024, 1, 1)..Date.new(2024, 12, 31)
price_range = 10.0...100.0  # Excludes 100

# Store
event = Event.create!(dates: '2024-01-01'::date..'2024-12-31'::date)

# Query overlaps
Event.where("dates && ?::daterange", '2024-06-01'::date..'2024-07-01'::date)

# Contains range
Event.where("dates @> ?::daterange", '2024-06-01'::date..'2024-06-15'::date)

# Contained by
Event.where("?::daterange @> dates", '2024-01-01'::date..'2024-12-31'::date)

# Before/after
Event.where("dates << ?::daterange", '2024-12-01'::date..'2024-12-31'::date)
```

## Array as Enum Alternative

```ruby
# Instead of separate enum table
class Post < ApplicationRecord
  STATUSES = ['draft', 'published', 'archived'].freeze
  validates :status, inclusion: { in: STATUSES }
end

# Use array for multiple values
class User < ApplicationRecord
  ROLES = ['user', 'admin', 'moderator'].freeze
  validates :roles, presence: true
  validate :roles_valid
  
  def roles_valid
    unless roles.all? { |role| ROLES.include?(role) }
      errors.add(:roles, 'contains invalid role')
    end
  end
end
```
