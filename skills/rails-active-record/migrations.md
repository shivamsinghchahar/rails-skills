# Migrations and Schema Management

Create and manage database schema changes through Rails migrations. Migrations provide a way to evolve your database schema over time while maintaining consistency.

## Quick Start

### Generate a Migration

```bash
# Generate migration for creating a table
rails generate migration CreateUsers name:string email:string

# Generate migration to add a column
rails generate migration AddStatusToUsers status:string
```

### Create Migration File

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.timestamps
    end
  end
end
```

### Run Migrations

```bash
# Run all pending migrations
rails db:migrate

# Check migration status
rails db:migrate:status

# Rollback last migration
rails db:rollback STEP=1

# Rollback all migrations
rails db:migrate VERSION=0
```

## Migration Patterns

### Single Responsibility

Each migration should do one logical thing. Avoid multi-step migrations.

```ruby
# Good: Single concern
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.timestamps
    end
  end
end

# Bad: Multiple concerns
class CreateUsersAndPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :users { |t| t.string :email }
    create_table :posts { |t| t.string :title }
  end
end
```

### Reversibility

Always use `change` method when possible. It auto-reverses on rollback.

```ruby
# Good: Reversible
def change
  add_column :users, :status, :string, default: 'active'
end

# Bad: Not reversible
def up
  execute "UPDATE users SET status = 'active' WHERE status IS NULL"
end

def down
  # What was the original state?
end
```

### Making Irreversible Changes Reversible

Use `reversible` block for complex changes:

```ruby
class AddPublishedAtToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :published_at, :datetime
    
    reversible do |direction|
      direction.up { Post.update_all(published_at: Time.current) }
    end
    
    change_column_null :posts, :published_at, false
  end
end
```

## Data Migrations

### Zero-Downtime Pattern

For large tables, use batching:

```ruby
class PopulateUserFullNames < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    User.in_batches(of: 1000) do |batch|
      batch.update_all("full_name = CONCAT(first_name, ' ', last_name)")
    end
  end
end
```

### Backfill Data in Batches

```ruby
class BackfillUserInitials < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :users, :initials, :string
    
    reversible do |direction|
      direction.up do
        User.in_batches(of: 5000) do |batch|
          batch.each do |user|
            initials = user.full_name.split.map(&:first).join
            user.update_column(:initials, initials)
          end
        end
      end
    end
  end
end
```

### Remove Column Safely

Column removal requires two deployments to avoid race conditions:

**Deployment 1:** Stop application from reading column

```ruby
class IgnoreDeprecatedColumn < ActiveRecord::Migration[7.1]
  def change
    # Remove from model: self.ignored_columns = ['deprecated_field']
  end
end
```

**Deployment 2:** Drop the column

```ruby
class RemoveDeprecatedColumn < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_column :users, :deprecated_field, :string
  end
end
```

## Common Migration Tasks

### Create Table with Foreign Keys

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    
    add_index :posts, [:user_id, :created_at]
  end
end
```

### Add Column with Null Constraint

```ruby
class AddStatusToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :status, :string
    User.update_all(status: 'active')
    change_column_null :users, :status, false
    change_column_default :users, :status, from: nil, to: 'active'
  end
end
```

### Rename Column Safely

```ruby
class RenameUserNameToFullName < ActiveRecord::Migration[7.1]
  def change
    rename_column :users, :name, :full_name
  end
end
```

### Create Enum Column (PostgreSQL)

```ruby
class AddStatusToUsers < ActiveRecord::Migration[7.1]
  def change
    create_enum :user_status, ['active', 'inactive', 'banned']
    add_column :users, :status, :enum, enum_type: :user_status, default: 'active'
  end
end
```

### Drop Table Safely

```ruby
class DropLegacyTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :legacy_users, if_exists: true
  end
end
```

### Add JSON Column

```ruby
class AddMetadataToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :metadata, :jsonb, default: {}, null: false
    add_index :users, :metadata, using: :gin
  end
end
```

## Concurrent Index Creation

For production indexes on large tables, use `algorithm: :concurrently`:

```ruby
class AddEmailIndexToUsers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

## Foreign Keys

Always use referential integrity:

```ruby
class AddUserRefToPosts < ActiveRecord::Migration[7.1]
  def change
    add_reference :posts, :user, null: false, foreign_key: true
  end
end
```

## Best Practices

- **One change per migration**: Keep migrations focused on a single change
- **Use reversible migrations**: Always use `change` method when possible
- **Batch data updates**: Use `in_batches` for large data migrations
- **Disable DDL transactions for long-running migrations**: Use `disable_ddl_transaction!` for data migrations
- **Test rollbacks**: Always test that migrations can be rolled back safely
- **Name migrations clearly**: Use descriptive names that explain the change
- **Avoid raw SQL**: Use Rails migration methods unless absolutely necessary
- **Use foreign keys**: Maintain referential integrity with foreign key constraints
- **Create indexes for foreign keys**: Improves query performance
- **Be careful with column removal**: Consider a two-step deployment process
