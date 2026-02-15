# Model Inheritance

Rails provides two strategies for inheritance: Single Table Inheritance (STI) and Class Table Inheritance. STI is simpler but comes with trade-offs, while Class Table Inheritance provides more flexibility at the cost of additional complexity.

## Single Table Inheritance (STI)

Single Table Inheritance stores different types of records in a single table, distinguished by a "type" column that holds the class name.

### Basic STI Setup

```ruby
# app/models/vehicle.rb
class Vehicle < ApplicationRecord
  # Specifying types in the class makes them explicit
end

# app/models/car.rb
class Car < Vehicle
end

# app/models/truck.rb
class Truck < Vehicle
end

# Database schema
create_table :vehicles do |t|
  t.string :type  # This stores the class name
  t.string :make
  t.string :model
  t.integer :doors  # Car-specific
  t.integer :cargo_capacity  # Truck-specific
  t.timestamps
end
```

### Creating and Querying STI Records

```ruby
# Creating records
car = Car.create(make: "Toyota", model: "Camry", doors: 4)
truck = Truck.create(make: "Ford", model: "F-150", cargo_capacity: 3500)

# The type column automatically stores the class name
car.type  # => "Car"
truck.type  # => "Truck"

# Query by type
Car.all  # Only cars
Truck.all  # Only trucks
Vehicle.all  # All vehicles (cars, trucks, etc.)

# Inheritance in queries
Vehicle.where(make: "Toyota")  # All Toyotas regardless of type
```

### STI with Subclass-Specific Attributes

```ruby
class Vehicle < ApplicationRecord
  validates :make, :model, presence: true
end

class Car < Vehicle
  validates :doors, numericality: { only_integer: true, greater_than: 0 }
  
  def display_info
    "#{make} #{model} (#{doors}-door)"
  end
end

class Truck < Vehicle
  validates :cargo_capacity, numericality: { greater_than: 0 }
  
  def display_info
    "#{make} #{model} (#{cargo_capacity} lb capacity)"
  end
end

car = Car.new(make: "Honda", model: "Civic", doors: 2)
truck = Truck.new(make: "Chevy", model: "Silverado", cargo_capacity: 5000)

# Polymorphic behavior: same method, different implementations
car.display_info  # => "Honda Civic (2-door)"
truck.display_info  # => "Chevy Silverado (5000 lb capacity)"
```

### STI Scopes and Queries

```ruby
class Vehicle < ApplicationRecord
  # All vehicles
  scope :recent, -> { order(created_at: :desc) }
  scope :by_make, ->(make) { where(make: make) }
end

class Car < Vehicle
  # Car-specific query
  scope :four_doors, -> { where(doors: 4) }
  scope :sedan, -> { four_doors.where(model: 'Camry') }
end

# Usage
Car.recent  # Only recent cars
Vehicle.by_make("Toyota").recent  # All recent Toyotas
Car.sedan  # Sedans (4-door)
```

## Advantages and Disadvantages of STI

**Advantages:**
- Simple database schema (single table)
- Easy to add new subclasses
- Inherited associations work naturally
- Good for closely related record types

**Disadvantages:**
- One table stores all columns for all types (sparse data)
- Adding type-specific columns adds NULL values for other types
- Harder to enforce type-specific NOT NULL constraints
- Migrations are shared across all types
- Can become unwieldy with many subclasses

## Class Table Inheritance

Class Table Inheritance (also called Joined Table Inheritance) uses a separate table for each model in the hierarchy, joined by a foreign key.

### Class Table Inheritance Setup

```ruby
# app/models/vehicle.rb
class Vehicle < ApplicationRecord
  self.inheritance_column = :type  # Specifies inheritance
end

# app/models/car.rb
class Car < Vehicle
  # This creates a separate cars table with vehicle_id FK
end

# app/models/truck.rb
class Truck < Vehicle
  # This creates a separate trucks table with vehicle_id FK
end

# Database schema
create_table :vehicles do |t|
  t.string :type
  t.string :make
  t.model
  t.timestamps
end

create_table :cars do |t|
  t.references :vehicle, foreign_key: true
  t.integer :doors
  t.timestamps
end

create_table :trucks do |t|
  t.references :vehicle, foreign_key: true
  t.integer :cargo_capacity
  t.timestamps
end
```

### Using Class Table Inheritance

```ruby
car = Car.create(make: "Toyota", model: "Camry", doors: 4)
truck = Truck.create(make: "Ford", model: "F-150", cargo_capacity: 3500)

# Each type has its own table
car.vehicle_id  # References the vehicles table
truck.vehicle_id  # References the vehicles table

# Query by type
Car.all  # Only cars (joined with vehicles)
Truck.all  # Only trucks (joined with vehicles)
Vehicle.all  # All vehicles (with their specific type data)
```

**Note:** Rails doesn't provide built-in Class Table Inheritance in the same way STI works. You typically need to use gems like `single_table_inheritance` or manage the association manually.

## Polymorphic Associations (Better Alternative)

For many inheritance scenarios, polymorphic associations are a better fit than STI or Class Table Inheritance. See [associations.md](associations.md) for details on polymorphic associations.

```ruby
# Instead of inheritance:
# Vehicle -> Car, Truck

# Use polymorphic associations:
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class Photo < ApplicationRecord
  has_many :comments, as: :commentable
end
```

## When to Use Each Approach

**Single Table Inheritance (STI):**
- Different types are closely related (share most attributes)
- Fewer than 5-10 types
- Type-specific attributes are optional or sparse
- Types behave similarly with minor variations

**Polymorphic Associations:**
- Unrelated models need the same relationship (comments, likes, notifications)
- Models are in different domains
- Different types have very different structures

**Class Table Inheritance:**
- Type-specific tables with different columns
- Each type needs different constraints
- Using a gem that supports it properly

## STI Best Practices

- **Limit inheritance depth**: Avoid deep hierarchies (Vehicle -> Car -> SportsCar -> Coupe)
- **Keep type logic simple**: Move complex behavior to services or concerns
- **Document type attributes**: Make clear which columns apply to which types
- **Use type-specific scopes**: Help filter records correctly
- **Consider alternative hierarchies**: Sometimes a composition approach is cleaner

```ruby
# Instead of deep inheritance
class Vehicle < ApplicationRecord; end
class Car < Vehicle; end
class SportsCar < Car; end
class Coupe < SportsCar; end

# Consider composition
class Vehicle < ApplicationRecord
  has_one :sports_package, dependent: :destroy
  
  scope :sports_cars, -> { includes(:sports_package).where.not(sports_packages: { id: nil }) }
end

class SportsPackage < ApplicationRecord
  belongs_to :vehicle
end
```

## STI Gotchas

**Querying Non-STI Models:**
```ruby
# Rails caches type queries; watch for unexpected results
Vehicle.find(1)  # Might return a Car instance
Car.find(1)  # Definitely returns a Car instance

# Always use the right class for explicit querying
```

**Validations Scope:**
```ruby
# Validations run for all subclasses
class Vehicle < ApplicationRecord
  validates :doors, presence: true  # Now required for all vehicles!
end

# Better approach
class Vehicle < ApplicationRecord; end

class Car < Vehicle
  validates :doors, presence: true  # Only for cars
end
```

**Default Scope Considerations:**
```ruby
class Vehicle < ApplicationRecord
  default_scope { order(created_at: :desc) }
end

# This applies to ALL vehicles, including when queried from Car.all
Car.all  # Uses the default scope
```
