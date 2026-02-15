# UUID Setup

## Enable UUID Extension

Migration:

```ruby
class EnablePgcryptoExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto'
  end
end
```

## UUID Primary Key

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :email
      t.timestamps
    end
  end
end

# Or in model
class User < ApplicationRecord
  self.primary_key = 'id'
end
```

## UUID Associations

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts, id: :uuid do |t|
      t.uuid :user_id, null: false, default: -> { 'gen_random_uuid()' }
      t.string :title
      t.timestamps
    end
    
    add_index :posts, :user_id
    add_foreign_key :posts, :users
  end
end

# Model
class Post < ApplicationRecord
  belongs_to :user
end
```

## Benefits

- **Distributed systems**: Generate IDs anywhere without coordination
- **Privacy**: User IDs not sequential/guessable
- **URL-safe**: No need to encrypt IDs in URLs
- **Natural randomness**: No sequential predictability

## Considerations

- Larger than integer (16 bytes vs 4 bytes)
- Slightly slower index lookups than integer
- Not suitable for sequential ordering
- Use when privacy/distribution benefits matter
