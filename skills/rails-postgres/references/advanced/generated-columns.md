# Generated Columns

Generated columns (stored or virtual) are computed from other columns. Available since PostgreSQL 12.

## Virtual Generated Columns

Virtual columns are computed on-the-fly and not stored:

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.virtual :full_name, type: :string, as: "CONCAT(first_name, ' ', last_name)"
      t.timestamps
    end
  end
end

class User < ApplicationRecord
end

# Usage
user = User.create(first_name: "John", last_name: "Doe")
user.full_name  # => "John Doe"

# Query
User.where("full_name LIKE ?", "John%")
```

## Stored Generated Columns

Stored columns are computed once and stored in the database:

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.virtual :full_name, 
                type: :string, 
                as: "CONCAT(first_name, ' ', last_name)", 
                stored: true
      t.timestamps
    end
  end
end

class User < ApplicationRecord
end

# Usage - same as virtual, but stored and indexable
user = User.create(first_name: "Jane", last_name: "Smith")
user.full_name  # => "Jane Smith"

# Can add index on stored generated column
add_index :users, :full_name
```

## Use Cases

### Uppercase for Full-Text Search

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.string :title
      t.virtual :title_upper, 
                type: :string, 
                as: "UPPER(title)", 
                stored: true
      t.timestamps
    end
    
    add_index :posts, :title_upper
  end
end

class Post < ApplicationRecord
end

# Case-insensitive search via index
Post.where(title_upper: "HELLO WORLD")
```

### Computed Totals

```ruby
class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.decimal :subtotal
      t.decimal :tax_rate
      t.virtual :total, 
                type: :decimal,
                precision: 10, 
                scale: 2,
                as: "subtotal * (1 + tax_rate / 100.0)",
                stored: true
      t.timestamps
    end
  end
end
```

### Year Extraction

```ruby
class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.datetime :published_at
      t.virtual :published_year, 
                type: :integer,
                as: "EXTRACT(YEAR FROM published_at)",
                stored: true
      t.timestamps
    end
    
    add_index :articles, :published_year
  end
end

class Article < ApplicationRecord
end

# Query by year efficiently
Article.where(published_year: 2024)
```

## Limitations

- Cannot reference generated columns in other generated columns
- Cannot use non-deterministic functions (NOW(), RANDOM())
- Columns are read-only in the application layer
- Cannot create indexes on virtual (non-stored) columns
