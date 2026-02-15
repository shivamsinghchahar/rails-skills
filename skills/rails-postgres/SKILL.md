---
name: rails-postgres
description: Master PostgreSQL in Rails with native types (UUID, JSON/JSONB, arrays, enums), efficient queries, indexes, and optimization. Use when designing databases, writing complex queries, using PostgreSQL-specific features, optimizing performance, or working with specialized data types.
---

# PostgreSQL in Rails

Comprehensive guide to using PostgreSQL's powerful features with Rails. Covers datatypes, queries, optimization, indexing, and advanced features for building robust, performant applications.

## Quick Start

Enable extensions and create a table with PostgreSQL types:

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    
    create_table :posts, id: :uuid do |t|
      t.string :title, null: false
      t.text :content
      t.jsonb :metadata, default: {}, null: false
      t.string :tags, array: true, default: []
      t.enum :status, enum_type: :post_status, default: 'draft'
      t.timestamps
    end
    
    add_index :posts, :metadata, using: :gin
    add_index :posts, :tags, using: :gin
  end
end
```

Access data in models:

```ruby
class Post < ApplicationRecord
  store_accessor :metadata, :author, :seo_keywords
  enum status: { draft: 'draft', published: 'published', archived: 'archived' }, prefix: true
end

# Usage
post = Post.create(title: "Hello", tags: ['rails'], metadata: { author: 'John' })
post.author # => 'John'
post.status_published! # => sets status to 'published'
```

## Core Topics

**Datatypes** - UUID, JSON/JSONB, arrays, ranges, enums, and custom types. See [references/datatypes/](references/datatypes/) for detailed guides on each type.

**Queries** - SQL patterns, joins, aggregations, subqueries, and raw SQL. See [references/queries/](references/queries/) for query patterns and real-world examples.

**Performance** - Indexes, query plans, optimization, and N+1 resolution. See [references/performance/](references/performance/) for strategies and best practices.

**Advanced Features** - Constraints, generated columns, full-text search, and database views. See [references/advanced/](references/advanced/) for specialized topics.

## When to Use This Skill

- Designing Rails database schemas with PostgreSQL datatypes
- Writing complex SQL queries and optimizing performance
- Setting up UUID primary keys and associations
- Working with JSON, arrays, or enums in migrations
- Debugging slow queries or creating indexes
- Using PostgreSQL-specific features like constraints or views
