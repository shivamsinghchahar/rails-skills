# Multiple Databases and Replicas

Advanced Active Record patterns for managing multiple databases, read replicas, and horizontal sharding in Rails applications.

## When to Use This Topic

- Scaling applications with multiple database servers
- Implementing read replicas for load distribution and performance
- Setting up writer and read-only database configurations
- Building multi-tenant applications with horizontal sharding
- Handling automatic connection switching based on HTTP verbs

## Configuration Setup

### Three-tier Database Configuration

The foundation of multiple databases in Rails is a three-tier configuration in `config/database.yml`. Each environment can have multiple named database configurations.

```yaml
production:
  primary:
    database: my_primary_database
    adapter: mysql2
    username: root
    password: <%= ENV['ROOT_PASSWORD'] %>
  
  primary_replica:
    database: my_primary_database
    username: root_readonly
    password: <%= ENV['ROOT_READONLY_PASSWORD'] %>
    adapter: mysql2
    replica: true
  
  animals:
    database: my_animals_database
    username: animals_root
    password: <%= ENV['ANIMALS_ROOT_PASSWORD'] %>
    adapter: mysql2
    migrations_paths: db/animals_migrate
  
  animals_replica:
    database: my_animals_database
    username: animals_readonly
    password: <%= ENV['ANIMALS_READONLY_PASSWORD'] %>
    adapter: mysql2
    replica: true
```

Key points:
- The `primary` configuration is the default if no explicit name is given
- Replicas must have `replica: true` flag so Rails doesn't run migrations against them
- Writer and replica databases must contain the same data
- Usernames should differ (writers can write, replicas are read-only)
- Different databases can have separate `migrations_paths`

### Model Connection Setup

Create abstract base classes to connect models to specific databases:

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  connects_to database: { writing: :primary, reading: :primary_replica }
end

# app/models/animals_record.rb
class AnimalsRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :animals, reading: :animals_replica }
end
```

Then models inherit from their appropriate base class:

```ruby
class Dog < AnimalsRecord
  # Automatically connects to animals database
end

class Person < ApplicationRecord
  # Automatically connects to primary database
end
```

### Connection Role Configuration

By default, Rails uses `:writing` and `:reading` roles. For legacy systems with different role names:

```ruby
# config/application.rb
config.active_record.writing_role = :default
config.active_record.reading_role = :readonly
```

## Automatic Connection Switching

### Middleware Setup

Rails can automatically switch between writer and replica databases based on the HTTP verb and recent writes:

```bash
bin/rails g active_record:multi_db
```

Uncomment the generated configuration in `config/initializers/multi_db.rb`:

```ruby
Rails.application.configure do
  config.active_record.database_selector = { delay: 2.seconds }
  config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
end
```

The middleware implements "read your own write" semantics:
- POST, PUT, DELETE, PATCH requests go to the writer
- GET, HEAD requests go to the replica (unless a write occurred within the `delay` window)
- This prevents race conditions where users see stale data they just wrote

### Custom Resolver

For cookie-based or other custom switching logic:

```ruby
class MyCookieResolver < ActiveRecord::Middleware::DatabaseSelector::Resolver
  def self.call(request)
    new(request.cookies)
  end

  def initialize(cookies)
    @cookies = cookies
  end

  attr_reader :cookies

  def last_write_timestamp
    self.class.convert_timestamp_to_time(cookies[:last_write])
  end

  def update_last_write_timestamp
    cookies[:last_write] = self.class.convert_time_to_timestamp(Time.now)
  end

  def save(response)
  end
end
```

Configure the custom resolver:

```ruby
config.active_record.database_selector = { delay: 2.seconds }
config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
config.active_record.database_resolver_context = MyCookieResolver
```

## Manual Connection Switching

### Role-based Switching

For fine-grained control over which database to use in specific code blocks:

```ruby
# Read from the replica for this query
ActiveRecord::Base.connected_to(role: :reading) do
  users = User.all  # Queries the replica
end

# Write to the writer database
ActiveRecord::Base.connected_to(role: :writing) do
  user = User.create(name: "Alice")  # Queries the writer
end
```

### Granular Database Switching

Switch connections for specific database classes without affecting others:

```ruby
# Only AnimalsRecord uses :reading role
AnimalsRecord.connected_to(role: :reading) do
  dog = Dog.first  # Reads from animals_replica
  person = Person.first  # Still reads from primary_replica
end
```

### Prevent Writes in Read Blocks

Ensure queries are read-only by raising errors on write attempts:

```ruby
ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
  # Any writes will raise an error
  User.create(name: "Bob")  # Raises
end
```

## Horizontal Sharding

Horizontal sharding splits data across multiple databases while maintaining the same schema. This is useful for multi-tenant applications.

### Configuration

```yaml
production:
  primary:
    database: my_primary_database
    adapter: mysql2
  
  primary_shard_one:
    database: my_primary_shard_one
    adapter: mysql2
    migrations_paths: db/migrate_shards
  
  primary_shard_one_replica:
    database: my_primary_shard_one
    adapter: mysql2
    replica: true
  
  primary_shard_two:
    database: my_primary_shard_two
    adapter: mysql2
    migrations_paths: db/migrate_shards
  
  primary_shard_two_replica:
    database: my_primary_shard_two
    adapter: mysql2
    replica: true
```

### Model Setup

```ruby
class ShardRecord < ApplicationRecord
  self.abstract_class = true
  
  connects_to shards: {
    shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica },
    shard_two: { writing: :primary_shard_two, reading: :primary_shard_two_replica }
  }
end

class Person < ShardRecord
  # Can be sharded
end
```

### Shard-aware Queries

Specify both role and shard when querying:

```ruby
ShardRecord.connected_to(role: :writing, shard: :shard_one) do
  person = Person.create!(name: "Alice")  # Created in shard_one
end

ShardRecord.connected_to(role: :writing, shard: :shard_two) do
  person2 = Person.create!(name: "Bob")  # Created in shard_two
end

# Can't find person in shard_two if created in shard_one
ShardRecord.connected_to(role: :writing, shard: :shard_two) do
  Person.find(person.id)  # Not found
end
```

### Automatic Shard Switching

```bash
bin/rails g active_record:multi_db
```

Configure automatic shard resolution in `config/initializers/multi_db.rb`:

```ruby
Rails.application.configure do
  config.active_record.shard_selector = { lock: true }
  config.active_record.shard_resolver = ->(request) {
    Tenant.find_by!(host: request.host).shard
  }
end
```

## Associations Across Databases

### The Problem

Joins across databases are not supported because databases can't execute joins on remote tables.

### Solution: disable_joins

Disable joins for associations that span databases:

```ruby
class Dog < AnimalsRecord
  has_many :treats, through: :humans, disable_joins: true
  has_many :humans
  
  has_one :yard, through: :home, disable_joins: true
end

class Human < AnimalsRecord
  has_many :treats
end

class Treat
  belongs_to :human
end

class Home
  has_one :yard
end
```

When you call `@dog.treats` with `disable_joins: true`, Rails generates multiple queries:

```ruby
# Instead of: SELECT treats.* FROM treats JOIN humans ON treats.human_id = humans.id
# Rails does:
SELECT "humans"."id" FROM "humans" WHERE "humans"."dog_id" = ?
SELECT "treats".* FROM "treats" WHERE "treats"."human_id" IN (?, ?, ?)
```

**Performance Considerations:**
- Multiple queries may be slower than a single join
- Large result sets can lead to too many IDs in the IN clause
- Order/limit is applied in-memory, not at the database level

## Advanced Patterns

### Read-after-Write Consistency

Ensure users always read their own writes immediately:

```ruby
# In a controller
def create
  @user = User.create!(name: params[:name])
  
  # Read back from writer immediately
  ActiveRecord::Base.connected_to(role: :writing) do
    @user = User.find(@user.id)
  end
  
  redirect_to @user
end
```

### Session-aware Replica Routing

Track writes per user and route subsequent reads to the writer within a grace period:

```ruby
class ApplicationController < ActionController::Base
  before_action :track_last_write
  
  private
  
  def track_last_write
    session[:last_write_time] = Time.current if request.post?
  end
  
  def should_use_replica?
    return false if session[:last_write_time].blank?
    
    elapsed = Time.current - session[:last_write_time]
    elapsed > 5.seconds  # Use replica if more than 5 seconds since write
  end
end
```

### Schema Caching for Performance

Load schema cache for each database to improve performance:

```ruby
# config/application.rb
config.active_record.lazily_load_schema_cache = true

# config/database.yml (per database)
production:
  primary:
    schema_cache_path: db/primary_schema_cache.yml
  animals:
    schema_cache_path: db/animals_schema_cache.yml
```

## Best Practices

1. **Always use abstract classes**: Don't connect individual models to the same database to limit connection pool exhaustion
2. **Set replica correctly**: Missing `replica: true` can cause data loss if migrations run against replicas
3. **Monitor replica lag**: Implement health checks for replica freshness
4. **Test failover**: Ensure your application handles replica failures gracefully
5. **Use connection pooling**: Configure appropriate pool sizes for multiple databases
6. **Document sharding keys**: Make it clear which column determines shard placement
7. **Avoid cross-shard transactions**: Multiple shards can't guarantee ACID properties
