# Composite Primary Keys

Using multiple columns as the primary key for tables where a single `id` column isn't sufficient to uniquely identify rows.

## When to Use This Topic

- Working with legacy database schemas that lack a single `id` primary key
- Implementing multi-tenant systems where data is partitioned by tenant and entity ID
- Building sharding systems where shard key + entity ID together uniquely identify records
- Designing junction tables with natural composite keys
- Migrating from single-key to composite-key schemas

## What Are Composite Primary Keys?

A composite primary key uses two or more columns to uniquely identify a row. For example:

```ruby
# Instead of: id = 42
# With composite key: store_id = 3, sku = "XYZ12345"
```

**Considerations:**
- Increases schema complexity
- Can be slower than single integer IDs
- Requires careful handling in associations
- Only use when necessary

## Creating Tables with Composite Primary Keys

### Basic Migration

```ruby
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, primary_key: [:store_id, :sku] do |t|
      t.integer :store_id, null: false
      t.string :sku, null: false
      t.text :description
      t.timestamps
    end
    
    add_index :products, [:store_id, :sku], unique: true
  end
end
```

The columns listed in `primary_key:` must be present in the table definition.

### Multi-tenant Composite Key

For multi-tenant systems:

```ruby
class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles, primary_key: [:account_id, :user_id] do |t|
      t.integer :account_id, null: false
      t.integer :user_id, null: false
      t.string :display_name
      t.text :bio
      t.timestamps
    end
  end
end
```

## Declaring Composite Primary Keys in Models

### Model Setup

```ruby
class Product < ApplicationRecord
  self.primary_key = [:store_id, :sku]
end
```

## Querying with Composite Keys

### Finding Records

Pass an array of values matching the primary key order:

```ruby
# Find a single record
product = Product.find([3, "XYZ12345"])
# => #<Product store_id: 3, sku: "XYZ12345", description: "Yellow socks">

# Find multiple records (array of arrays)
products = Product.find([[1, "ABC98765"], [7, "ZZZ11111"]])
# => [#<Product store_id: 1, sku: "ABC98765", ...>, #<Product store_id: 7, sku: "ZZZ11111", ...>]
```

The SQL generated uses all composite key columns:

```sql
SELECT * FROM products WHERE store_id = 3 AND sku = 'XYZ12345'
```

### Ordering

Models with composite keys order by all key columns:

```ruby
first_product = Product.first
# => #<Product store_id: 1, sku: "ABC98765", ...>
```

Generates SQL:

```sql
SELECT * FROM products ORDER BY products.store_id ASC, products.sku ASC LIMIT 1
```

### Where Conditions

Use tuple-like syntax for composite key conditions:

```ruby
# Using the primary key columns
Product.where(Product.primary_key => [[1, "ABC98765"], [7, "ZZZ11111"]])

# Using individual column conditions
Product.where(store_id: 1, sku: "ABC98765")
```

### Important: find_by with :id

The `id` parameter in `find_by` matches an `:id` attribute, not the primary key:

```ruby
class Book < ApplicationRecord
  self.primary_key = [:author_id, :id]
end

# WRONG: Looks for :id attribute, not the composite key
Book.find_by(id: 5)

# CORRECT: Use primary key columns explicitly
Book.find_by(author_id: 2, id: 5)
```

## Associations with Composite Primary Keys

### The Challenge

Rails typically infers relationships by matching primary key to foreign key. With composite keys, you must explicitly specify which columns to use.

### Default Behavior (When :id is in the Key)

If the composite key includes an `:id` column that's unique on its own:

```ruby
class Order < ApplicationRecord
  self.primary_key = [:shop_id, :id]
  has_many :books
end

class Book < ApplicationRecord
  belongs_to :order
end
```

Rails assumes `:id` is sufficient for the association (shortcut):

```ruby
# The association uses only :id, not [:shop_id, :id]
order = Order.create!(id: [1, 2], status: "pending")
book = order.books.create!(title: "A Cool Book")

# When accessing the order:
book.reload.order
# Generates: SELECT * FROM orders WHERE id = 2
```

This works **only if** the `:id` column is unique across all records.

### Explicit Composite Foreign Keys

Specify the full composite key for associations:

```ruby
class Author < ApplicationRecord
  self.primary_key = [:first_name, :last_name]
  has_many :books, foreign_key: [:author_first_name, :author_last_name]
end

class Book < ApplicationRecord
  belongs_to :author, foreign_key: [:author_first_name, :author_last_name]
  
  # Migration: add columns for composite foreign key
  # add_column :books, :author_first_name, :string
  # add_column :books, :author_last_name, :string
end
```

Usage:

```ruby
author = Author.create!(first_name: "Jane", last_name: "Doe")
book = author.books.create!(title: "A Cool Book", author_first_name: "Jane", author_last_name: "Doe")

# When accessing author, uses full composite key
book.reload.author
# Generates: SELECT * FROM authors WHERE first_name = 'Jane' AND last_name = 'Doe'
```

### Has One Through with Composite Keys

```ruby
class Store < ApplicationRecord
  self.primary_key = :store_id
  has_many :products, foreign_key: :store_id
end

class Product < ApplicationRecord
  self.primary_key = [:store_id, :sku]
  has_one :inventory, foreign_key: [:store_id, :product_sku]
end

class Inventory < ApplicationRecord
  belongs_to :product, foreign_key: [:store_id, :product_sku]
end
```

## Forms for Composite Primary Key Models

Rails automatically handles composite keys in forms:

```ruby
@book = Book.find([2, 25])
# => #<Book id: 25, author_id: 2, title: "Some book">

<%= form_with model: @book do |form| %>
  <%= form.text_field :title %>
  <%= form.submit %>
<% end %>
```

Generates a form with the URL `/books/2_25` (composite key delimited by underscore).

## Composite Key Parameters

Extract composite keys from controller parameters using `extract_value`:

```ruby
class BooksController < ApplicationController
  def show
    # Extract composite ID from URL parameters
    id = params.extract_value(:id)
    # => ["2", "25"] for URL "/books/2_25"
    
    # Pass to find (handles both string and integer arrays)
    @book = Book.find(id)
  end
end
```

With route:

```ruby
get "/books/:id", to: "books#show"
```

The `extract_value` method parses delimited composite keys from URL parameters.

## Fixtures with Composite Primary Keys

### Basic Fixtures

For models with composite keys that include an `:id` column, omit the `:id` as usual:

```ruby
class Book < ApplicationRecord
  self.primary_key = [:author_id, :id]
  belongs_to :author
end
```

```yaml
# test/fixtures/books.yml
alices_adventure:
  author_id: <%= ActiveRecord::FixtureSet.identify(:lewis_carroll) %>
  title: "Alice's Adventures in Wonderland"
```

### Composite Fixture IDs

For purely composite keys (no `:id` column), use `composite_identify`:

```ruby
class BookOrder < ApplicationRecord
  self.primary_key = [:shop_id, :id]
  belongs_to :order, foreign_key: [:shop_id, :order_id]
  belongs_to :book, foreign_key: [:author_id, :book_id]
end
```

```yaml
# test/fixtures/book_orders.yml
alices_in_bookstore:
  author_id: <%= ActiveRecord::FixtureSet.composite_identify(:alices_adventure, Book.primary_key)[:id] %>
  author_first_name: <%= ActiveRecord::FixtureSet.composite_identify(:alices_adventure, Book.primary_key)[:author_first_name] %>
  
  shop_id: 1
  order_id: <%= ActiveRecord::FixtureSet.composite_identify(:order_1, Order.primary_key)[:id] %>
```

## Scoping and Advanced Queries

### Default Scopes

Composite key models maintain scoping on all key columns:

```ruby
class Product < ApplicationRecord
  self.primary_key = [:store_id, :sku]
  
  scope :active, -> { where(archived: false) }
end

# Ordering includes all key columns
Product.active.first
# SELECT * FROM products WHERE archived = false ORDER BY store_id ASC, sku ASC LIMIT 1
```

### Reload with Composite Keys

Reloading works with composite keys:

```ruby
product = Product.first
product.description = "Updated"
product.reload  # Uses [:store_id, :sku] to reload

# Generates: SELECT * FROM products WHERE store_id = ? AND sku = ?
```

## Migration Path

### Adding Composite Keys to Existing Table

For existing tables with an `id` column:

```ruby
class AddCompositeKeyToProducts < ActiveRecord::Migration[8.1]
  def change
    # First, ensure the natural key columns are indexed
    add_index :products, [:store_id, :sku], unique: true
    
    # Then declare the composite key in the model
    # class Product < ApplicationRecord
    #   self.primary_key = [:store_id, :id]
    # end
  end
end
```

### Removing Composite Keys

To transition from composite to single-key:

```ruby
class SimplifyProductKeys < ActiveRecord::Migration[8.1]
  def change
    # Add a new single id column if needed
    add_column :products, :simple_id, :bigint, primary_key: true
    
    # Populate simple_id
    execute "UPDATE products SET simple_id = ROW_NUMBER() OVER (ORDER BY store_id, sku)"
    
    # Remove old composite primary key and update foreign keys
    # This is database-specific and complex
  end
end
```

## Performance Considerations

1. **Composite keys are slower than integer IDs**: Each query involves multiple column comparisons
2. **Index all key columns**: Create indexes on the composite key and any queries involving key columns
3. **Joins are more expensive**: Joining on multiple columns has higher overhead
4. **Foreign keys are larger**: Each child record stores multiple foreign key values
5. **Plan query patterns**: Optimize indexes based on how you query the data

## Best Practices

1. **Use only when necessary**: Single integer IDs are simpler and faster
2. **Keep composite keys small**: 2-3 columns is typical; avoid keys with many columns
3. **Document the key**: Make it clear in comments which columns form the primary key
4. **Test associations carefully**: Composite key associations are easy to get wrong
5. **Use explicit foreign keys**: Don't rely on Rails inference; explicitly specify `foreign_key`
6. **Index all key columns**: Ensure your database has indexes on the composite key
7. **Normalize representation**: Use consistent ordering of key columns across your application
