---
name: rails-active-record
description: Master Active Record for model associations, querying, validations, and advanced patterns in Rails applications
---

# Rails Active Record

Active Record is Rails' Object-Relational Mapping (ORM) layer that provides a clean, intuitive interface for interacting with database records as Ruby objects. It handles model definitions, relationships between models, data validation, persistence, and complex queries through a declarative, expressive API.

## When to Use This Skill

- Defining model relationships (has_many, belongs_to, polymorphic associations, through associations)
- Adding validations to ensure data integrity at the application level
- Building complex queries with scoping, eager loading, and joins
- Implementing inheritance patterns with single table inheritance (STI) or class table inheritance
- Optimizing database access patterns to prevent N+1 queries
- Working with callbacks for model lifecycle events
- Implementing soft deletes, auditing, and other advanced patterns
- Querying with conditions, aggregations, and complex WHERE clauses

## Quick Start

### Basic Model Definition

```bash
# Generate a User model
rails generate model User email:string name:string encrypted_password:string
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  validates :email, :name, presence: true
  validates :email, uniqueness: true
  
  has_many :posts, dependent: :destroy
  has_one :profile, dependent: :destroy
end

class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
end

class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user
end
```

### Querying

```ruby
# Find records
user = User.find(1)
user = User.find_by(email: "user@example.com")
users = User.where("created_at > ?", 1.week.ago)

# Eager loading to prevent N+1 queries
users = User.includes(:posts, :profile)

# Scopes
active_users = User.where(active: true)
recent_users = User.where("created_at > ?", 1.month.ago)

# Aggregations
user_count = User.count
total_posts = Post.sum(:views)
```

## Core Topics

**Associations**: See [associations.md](associations.md) for building relationships between models including `has_many`, `belongs_to`, `has_one`, polymorphic associations, and `through` associations.

**Validations**: See [validations.md](validations.md) for ensuring data integrity with presence, uniqueness, format, custom, and conditional validations.

**Inheritance**: See [inheritance.md](inheritance.md) for single table inheritance (STI), polymorphism, and class table inheritance patterns.

**Querying**: See [querying.md](querying.md) for scopes, eager loading with `includes` and `joins`, N+1 prevention, and complex query patterns.

**Migrations**: See [migrations.md](migrations.md) for creating and managing database schema changes, migration patterns, data migrations, and zero-downtime deployment strategies.

**Patterns**: See [patterns.md](patterns.md) for design patterns, callbacks, query optimization strategies, caching, soft deletes, and common pitfalls to avoid.

## Advanced Concepts

**Multiple Databases**: See [advanced-databases.md](advanced-databases.md) for managing multiple databases, read replicas, automatic connection switching, and horizontal sharding in production systems.

**Encryption**: See [advanced-encryption.md](advanced-encryption.md) for application-level attribute encryption, deterministic encryption for searchable fields, key rotation, and compliance with data protection regulations.

**Composite Primary Keys**: See [advanced-composite-keys.md](advanced-composite-keys.md) for using multiple columns as primary keys in legacy systems, multi-tenant applications, and advanced sharding scenarios.

**Advanced Patterns**: See [references/advanced-topics.md](references/advanced-topics.md) for real-world implementations combining multiple databases, encryption, and composite keys in production SaaS and e-commerce platforms.

## Examples

See [examples.md](examples.md) for practical, real-world implementations including:
- User-Post-Comment hierarchies with nested associations
- Polymorphic comments and tags
- Soft deletes and paranoia patterns
- Through associations and complex relationships
- Scoping and querying complex datasets

## Key Concepts

### Models and Tables

Every model maps to a database table (by default, plural form of the model name). Define models by creating a class that inherits from `ApplicationRecord`:

```ruby
# Models inherit from ApplicationRecord
class User < ApplicationRecord
  # Model code here
end
```

### Timestamps

Active Record automatically manages `created_at` and `updated_at` columns unless you disable them with `self.record_timestamps = false`.

### Database Migrations

Use migrations (see [migrations.md](migrations.md)) to define schema changes. Active Record uses migrations to keep your database schema in sync with your model definitions.

### Connections to Other Skills

- **Rails Postgres**: Leverage PostgreSQL-specific features like JSON columns, arrays, and advanced query patterns
- **Rails Testing with RSpec**: Test models, validations, associations, and query scopes with factories and mocking

## Official Resources

- [Active Record Basics](https://guides.rubyonrails.org/active_record_basics.html)
- [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
- [Active Record Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Association Basics](https://guides.rubyonrails.org/association_basics.html)
- [Active Record Querying](https://guides.rubyonrails.org/active_record_querying.html)
- [Active Model Basics](https://guides.rubyonrails.org/active_model_basics.html)
