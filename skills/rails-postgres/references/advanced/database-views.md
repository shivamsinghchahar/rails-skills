# Database Views

Database views create a virtual table based on a SQL query. Useful for simplifying complex queries or abstracting database structure.

## Basic View

```ruby
class CreateArticlesView < ActiveRecord::Migration[7.1]
  def change
    execute <<-SQL
      CREATE VIEW articles AS
      SELECT "INT_ID" AS id,
             "STR_TITLE" AS title,
             "STR_STAT" AS status,
             "DT_PUBL_AT" AS published_at,
             "BL_ARCH" AS archived
      FROM "TBL_ART"
      WHERE "BL_ARCH" = false
    SQL
  end
  
  def down
    execute 'DROP VIEW articles'
  end
end

class Article < ApplicationRecord
  self.primary_key = 'id'
end
```

## Updateable Views

Simple views can be updated directly:

```ruby
# Usage
article = Article.create(title: 'Winter is coming', status: 'published')
article.archive!

# This updates through the view into the underlying table
class Article < ApplicationRecord
  self.primary_key = 'id'
  
  def archive!
    update_attribute :archived, true
  end
end
```

## Complex View with Joins

```ruby
class CreateActivePostsView < ActiveRecord::Migration[7.1]
  def change
    execute <<-SQL
      CREATE VIEW active_posts AS
      SELECT p.id,
             p.title,
             p.content,
             u.name as author_name,
             COUNT(c.id) as comment_count
      FROM posts p
      JOIN users u ON u.id = p.user_id
      LEFT JOIN comments c ON c.post_id = p.id
      WHERE p.published = true
      GROUP BY p.id, p.title, p.content, u.name
    SQL
  end
  
  def down
    execute 'DROP VIEW active_posts'
  end
end

class ActivePost < ApplicationRecord
  self.table_name = 'active_posts'
  self.primary_key = 'id'
end

# Query
ActivePost.where('comment_count > ?', 5)
```

## Materialized Views

For expensive queries, use materialized views (snapshots):

```ruby
class CreateMonthlyStatsView < ActiveRecord::Migration[7.1]
  def change
    execute <<-SQL
      CREATE MATERIALIZED VIEW monthly_stats AS
      SELECT DATE_TRUNC('month', created_at)::date as month,
             COUNT(*) as post_count,
             AVG(views) as avg_views,
             SUM(views) as total_views
      FROM posts
      GROUP BY DATE_TRUNC('month', created_at)
      ORDER BY month DESC
    SQL
  end
  
  def down
    execute 'DROP MATERIALIZED VIEW monthly_stats'
  end
end

class MonthlyStat < ApplicationRecord
  self.table_name = 'monthly_stats'
  
  # Refresh view (runs the underlying query)
  def self.refresh
    ActiveRecord::Base.connection.execute('REFRESH MATERIALIZED VIEW monthly_stats')
  end
end

# Usage
MonthlyStat.refresh  # Update statistics
MonthlyStat.where('month > ?', 1.month.ago)
```

## Concurrent Materialized View Refresh

Avoid locking the view during refresh:

```ruby
class MonthlyStat < ApplicationRecord
  self.table_name = 'monthly_stats'
  
  def self.refresh
    ActiveRecord::Base.connection.execute(
      'REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_stats'
    )
  end
end
```

Note: Requires a unique index on the materialized view.

## View with Triggers

Make complex views updateable:

```ruby
class CreateArticlesView < ActiveRecord::Migration[7.1]
  def change
    execute <<-SQL
      CREATE VIEW articles AS
      SELECT id, title, status
      FROM tbl_art
      WHERE archived = false
    SQL
    
    # Create instead-of trigger for updates
    execute <<-SQL
      CREATE TRIGGER articles_update
      INSTEAD OF UPDATE ON articles
      FOR EACH ROW
      EXECUTE FUNCTION update_article()
    SQL
    
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_article()
      RETURNS TRIGGER AS $$
      BEGIN
        UPDATE tbl_art
        SET title = NEW.title, status = NEW.status
        WHERE id = NEW.id;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    SQL
  end
end
```

## Benefits of Views

- **Abstraction**: Hide complex joins behind simple interface
- **Reusability**: Share queries across application
- **Simplification**: Easier to read and maintain
- **Security**: Control which columns users can access
- **Performance**: Materialized views cache expensive computations
