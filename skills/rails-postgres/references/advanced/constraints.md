# Constraints and Foreign Keys

## Deferrable Foreign Keys

By default, PostgreSQL checks foreign key constraints immediately. Make them deferrable to allow circular dependencies within transactions:

```ruby
# Deferrable with immediate checking (default)
add_reference :person, :alias, foreign_key: { deferrable: :immediate }

# Deferrable with deferred checking
add_reference :person, :alias, foreign_key: { deferrable: :deferred }
```

## Creating Circular Dependencies

Without deferrable foreign keys, this fails:

```ruby
ActiveRecord::Base.connection.transaction do
  person = Person.create(id: SecureRandom.uuid, alias_id: SecureRandom.uuid, name: "John")
  # Fails! alias_id doesn't exist yet
  Alias.create(id: person.alias_id, person_id: person.id, name: "jaydee")
end
```

With deferrable foreign keys set to deferred:

```ruby
ActiveRecord::Base.connection.transaction do
  person = Person.create(id: SecureRandom.uuid, alias_id: SecureRandom.uuid, name: "John Doe")
  Alias.create(id: person.alias_id, person_id: person.id, name: "jaydee")
  # Constraint checked when transaction commits - both records exist
end
```

## Manual Constraint Deferral

```ruby
# Set immediate constraints to defer in transaction
ActiveRecord::Base.connection.transaction do
  ActiveRecord::Base.connection.set_constraints(:deferred)
  
  person = Person.create(alias_id: SecureRandom.uuid, name: "John Doe")
  Alias.create(id: person.alias_id, person_id: person.id, name: "jaydee")
end
```

## Unique Constraints

```ruby
class CreateItems < ActiveRecord::Migration[7.1]
  def change
    create_table :items do |t|
      t.integer :position, null: false
      t.unique_constraint [:position], deferrable: :immediate
    end
  end
end

# Convert existing unique index to constraint
add_unique_constraint :items, deferrable: :deferred, using_index: "index_items_on_position"
```

## Exclusion Constraints

Ensure no overlapping ranges (useful for scheduling):

```ruby
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.integer :price, null: false
      t.daterange :availability_range, null: false
      
      t.exclusion_constraint "price WITH =, availability_range WITH &&", 
                              using: :gist, 
                              name: "no_overlapping_availability"
    end
  end
end

# Example: Two products can't have same price with overlapping dates
Product.create(price: 100, availability_range: '2024-01-01'::date..'2024-12-31'::date)
# This fails:
Product.create(price: 100, availability_range: '2024-06-01'::date..'2024-07-31'::date)
```

## Check Constraints

```ruby
class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.decimal :price, precision: 10, scale: 2
      t.decimal :discount, precision: 10, scale: 2
      
      # Ensure discount doesn't exceed price
      t.check_constraint "discount <= price", name: "discount_not_greater_than_price"
    end
  end
end
```
