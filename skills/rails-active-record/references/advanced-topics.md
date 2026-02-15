# Advanced Patterns and Real-World Examples

Real-world implementations combining multiple database features with encryption and composite keys.

## Multi-tenant SaaS Application

### Architecture

A SaaS platform with:
- Encrypted customer PII
- Multiple databases with read replicas
- Sharded user data across tenants
- Composite keys for tenant-scoped uniqueness

### Schema

```ruby
# config/database.yml
production:
  primary:
    database: main_database
    adapter: postgresql
  primary_replica:
    database: main_database
    username: readonly_user
    adapter: postgresql
    replica: true
  
  tenant_shard_one:
    database: tenant_shard_1
    adapter: postgresql
    migrations_paths: db/tenant_migrations
  
  tenant_shard_one_replica:
    database: tenant_shard_1
    username: readonly_user
    adapter: postgresql
    replica: true
```

### Model Setup

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  connects_to database: { writing: :primary, reading: :primary_replica }
end

# app/models/tenant_record.rb
class TenantRecord < ApplicationRecord
  self.abstract_class = true
  connects_to shards: {
    shard_one: { writing: :tenant_shard_one, reading: :tenant_shard_one_replica },
    shard_two: { writing: :tenant_shard_two, reading: :tenant_shard_two_replica }
  }
end

# app/models/tenant.rb
class Tenant < ApplicationRecord
  # Primary database
  has_many :users
  encrypts :name
  
  def shard_key
    # Determine which shard this tenant's data belongs to
    (id % 2).zero? ? :shard_one : :shard_two
  end
end

# app/models/user.rb
class User < TenantRecord
  # Lives in sharded database
  self.primary_key = [:tenant_id, :id]
  
  belongs_to :tenant, foreign_key: :tenant_id
  has_many :subscriptions, foreign_key: [:tenant_id, :user_id]
  
  encrypts :email, deterministic: true
  encrypts :phone_number
  encrypts :ssn
  
  validates :email, uniqueness: { scope: :tenant_id }
end

# app/models/subscription.rb
class Subscription < TenantRecord
  self.primary_key = [:tenant_id, :id]
  
  belongs_to :user, foreign_key: [:tenant_id, :user_id]
  belongs_to :plan, foreign_key: :plan_id
end
```

### Usage

```ruby
# Find tenant
tenant = Tenant.find(42)

# Execute queries in the appropriate shard
TenantRecord.connected_to(role: :writing, shard: tenant.shard_key) do
  # Create user
  user = User.create!(
    tenant_id: tenant.id,
    email: "user@example.com",
    phone_number: "+1-555-0123",
    ssn: "123-45-6789"
  )
end

# Read from replica
TenantRecord.connected_to(role: :reading, shard: tenant.shard_key) do
  # Find by encrypted email
  user = User.find_by(email: "user@example.com")
end

# Automatic replica failover in controller
class UsersController < ApplicationController
  def show
    tenant = Tenant.find(params[:tenant_id])
    
    TenantRecord.connected_to(role: :reading, shard: tenant.shard_key) do
      @user = User.find([tenant.id, params[:id]])
    end
  end
  
  def create
    tenant = Tenant.find(params[:tenant_id])
    
    TenantRecord.connected_to(role: :writing, shard: tenant.shard_key) do
      @user = User.create!(user_params.merge(tenant_id: tenant.id))
    end
    
    redirect_to [@tenant, @user]
  end
end
```

## E-commerce Platform with Product Variants

### Problem

Products have multiple variants (size, color) at different stores. A natural composite key is (store_id, product_sku), but individual variants also need identity.

### Solution

```ruby
# app/models/store.rb
class Store < ApplicationRecord
  has_many :products, foreign_key: :store_id
  encrypts :api_key
end

# app/models/product.rb
class Product < ApplicationRecord
  self.primary_key = [:store_id, :sku]
  
  belongs_to :store, foreign_key: :store_id
  has_many :variants, foreign_key: [:store_id, :product_sku]
  
  encrypts :supplier_cost
end

# app/models/variant.rb
class Variant < ApplicationRecord
  self.primary_key = [:store_id, :product_sku, :variant_id]
  
  belongs_to :product, foreign_key: [:store_id, :product_sku]
  has_many :inventory_records, foreign_key: [:store_id, :product_sku, :variant_id]
end

# app/models/inventory_record.rb
class InventoryRecord < ApplicationRecord
  self.primary_key = [:store_id, :product_sku, :variant_id, :location_id]
  
  belongs_to :variant, foreign_key: [:store_id, :product_sku, :variant_id]
  belongs_to :location
end

# Migration
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, primary_key: [:store_id, :sku] do |t|
      t.integer :store_id, null: false
      t.string :sku, null: false
      t.string :name
      t.text :description
      t.string :supplier_cost  # Encrypted
      t.timestamps
    end
    add_index :products, [:store_id, :sku], unique: true
    
    create_table :variants, id: false do |t|
      t.integer :store_id, null: false
      t.string :product_sku, null: false
      t.integer :variant_id, null: false
      t.string :size
      t.string :color
      t.decimal :price, precision: 10, scale: 2
      t.timestamps
    end
    add_primary_key :variants, [:store_id, :product_sku, :variant_id]
    add_index :variants, [:store_id, :product_sku]
  end
end
```

### Operations

```ruby
# Find specific product variant
store = Store.find(3)
product = Product.find([3, "SHIRT-001"])
variant = Variant.find([3, "SHIRT-001", 42])

# Query variants by product
Variant.where(store_id: 3, product_sku: "SHIRT-001")

# Form with composite key
form_with model: @variant do |form|
  # Route: /stores/3/products/SHIRT-001/variants/42
  form.text_field :color
  form.submit
end

# Controller parameter extraction
def show
  id = params.extract_value(:id)  # ["3", "SHIRT-001", "42"]
  @variant = Variant.find(id)
end
```

## Healthcare Platform with Encryption and Replicas

### Requirements

- Encrypt all PII and health records
- Read-heavy queries using replicas
- Fast writes to primary for real-time updates
- Searchable encrypted fields (patient ID, email)

### Implementation

```ruby
# app/models/patient.rb
class Patient < ApplicationRecord
  has_many :medical_records
  has_many :test_results
  
  # Deterministic: searchable, unique constraint
  encrypts :email, deterministic: true
  encrypts :mrn, deterministic: true  # Medical Record Number
  
  # Non-deterministic: write-once sensitive data
  encrypts :ssn
  encrypts :insurance_id
  encrypts :blood_type
  
  validates :mrn, uniqueness: true
  validates :email, uniqueness: true
end

# app/models/medical_record.rb
class MedicalRecord < ApplicationRecord
  belongs_to :patient
  
  encrypts :diagnosis
  encrypts :medications
  encrypts :allergies
  
  # Non-deterministic: large content
  encrypts :notes, compress: false
end

# app/models/test_result.rb
class TestResult < ApplicationRecord
  belongs_to :patient
  
  encrypts :test_type, deterministic: true
  encrypts :result_value
  encrypts :normal_range
end

# Migration
class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      # Deterministic encrypted fields need larger columns (4x for UTF-8 encoding)
      t.string :email, limit: 1020
      t.string :mrn, limit: 510
      
      # Non-deterministic encrypted fields (base64 overhead)
      t.string :ssn, limit: 510
      t.string :insurance_id, limit: 510
      t.string :blood_type, limit: 255
      
      # Metadata
      t.date :date_of_birth
      t.string :name
      
      t.timestamps
    end
    
    add_index :patients, :mrn, unique: true
    add_index :patients, :email, unique: true
  end
end

# Controllers with replica routing
class PatientsController < ApplicationController
  def index
    # Use replica for list view
    ActiveRecord::Base.connected_to(role: :reading) do
      @patients = Patient.all.limit(50)
    end
  end
  
  def show
    # Use replica for detail view
    ActiveRecord::Base.connected_to(role: :reading) do
      @patient = Patient.find(params[:id])
      @medical_records = @patient.medical_records
    end
  end
  
  def create
    # Use writer for creation
    ActiveRecord::Base.connected_to(role: :writing) do
      @patient = Patient.create!(patient_params)
    end
    
    redirect_to @patient
  end
  
  def search
    # Search encrypted deterministic fields from replica
    ActiveRecord::Base.connected_to(role: :reading) do
      @patients = Patient.where(mrn: params[:mrn])
    end
  end
end
```

## Migration: Single Database to Multiple Databases with Encryption

### Phase 1: Enable Unencrypted Data Support

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

### Phase 2: Add Encrypted Attributes

```ruby
# app/models/user.rb
class User < ApplicationRecord
  encrypts :email, deterministic: true
  encrypts :phone
end

# Migration
class AddEncryptionToUsers < ActiveRecord::Migration[8.1]
  def change
    # Increase column size for encryption overhead
    change_column :users, :email, :string, limit: 1020
    change_column :users, :phone, :string, limit: 1020
  end
end
```

### Phase 3: Re-encrypt Existing Data

```ruby
# lib/tasks/encryption.rake
namespace :encryption do
  desc "Re-encrypt existing user data"
  task reencrypt_users: :environment do
    User.find_each do |user|
      user.encrypt
      user.save(validate: false)
      puts "Re-encrypted user #{user.id}"
    end
  end
end
```

Run: `bin/rails encryption:reencrypt_users`

### Phase 4: Add Replicas

```ruby
# config/database.yml
production:
  primary:
    database: production_db
    adapter: postgresql
  primary_replica:
    database: production_db
    username: readonly_user
    adapter: postgresql
    replica: true

# config/application.rb
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  connects_to database: { writing: :primary, reading: :primary_replica }
end
```

### Phase 5: Enable Automatic Switching

```bash
bin/rails g active_record:multi_db
```

Uncomment configuration in `config/initializers/multi_db.rb`.

### Phase 6: Disable Unencrypted Data Support

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = false
config.active_record.encryption.extend_queries = false
```

Verify all data is encrypted before this step!

## Testing Advanced Features

### Test Fixtures with Encryption

```yaml
# test/fixtures/users.yml
alice:
  email: alice@example.com  # Plain text in fixture
  phone: "555-0123"
  name: Alice

bob:
  email: bob@example.com
  phone: "555-0456"
  name: Bob
```

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.active_record.encryption.encrypt_fixtures = true
end

# test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test "encrypts email" do
    user = users(:alice)
    assert_equal "alice@example.com", user.email
    assert user.encrypted_attribute?(:email)
  end
  
  test "can find by encrypted deterministic email" do
    user = users(:alice)
    assert_equal user, User.find_by(email: "alice@example.com")
  end
end
```

### Testing with Multiple Databases

```ruby
# test/models/dog_test.rb
class DogTest < ActiveSupport::TestCase
  setup do
    # Create test data in appropriate shard
    @shard = :shard_one
  end
  
  test "creates dog in shard" do
    Dog.connected_to(role: :writing, shard: @shard) do
      @dog = Dog.create!(name: "Buddy")
    end
    
    Dog.connected_to(role: :reading, shard: @shard) do
      assert_equal "Buddy", Dog.find(@dog.id).name
    end
  end
end
```

### Testing Composite Keys

```ruby
# test/models/product_test.rb
class ProductTest < ActiveSupport::TestCase
  setup do
    @store_id = 1
    @sku = "PROD-001"
  end
  
  test "finds product by composite key" do
    product = Product.create!(store_id: @store_id, sku: @sku, name: "Widget")
    found = Product.find([@store_id, @sku])
    assert_equal product, found
  end
  
  test "supports composite key in forms" do
    @product = Product.find([@store_id, @sku])
    # URL is /products/1_PROD-001
    assert_includes product_path(@product), "1_PROD-001"
  end
end
```
