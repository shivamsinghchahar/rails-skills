# Active Record Encryption

Application-level attribute encryption for protecting sensitive data in your database with transparent encryption and decryption.

## When to Use This Topic

- Encrypting personally identifiable information (PII) like emails, phone numbers, SSNs
- Protecting sensitive data like credit card numbers or health information
- Meeting compliance requirements (GDPR, HIPAA, PCI-DSS)
- Encrypting data before it reaches the database
- Implementing deterministic encryption for searchable sensitive fields
- Supporting key rotation for encryption scheme changes

## Setup and Key Generation

### Generate Encryption Keys

```bash
bin/rails db:encryption:init
```

This generates three keys that should be stored in Rails credentials:

```bash
# Copy output into credentials file
bin/rails credentials:edit
```

```yaml
active_record_encryption:
  primary_key: YehXdfzxVKpoLvKseJMJIEGs2JxerkB8
  deterministic_key: uhtk2DYS80OweAPnMLtrV2FhYIXaceAy
  key_derivation_salt: g7Q66StqUQDQk9SJ81sWbYZXgiRogBwS
```

### Environment Variables

For deployment systems that don't use credentials:

```ruby
# config/application.rb
config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
```

Minimum key lengths:
- Primary key: 12 bytes
- Deterministic key: 20 bytes
- Key derivation salt: 20 bytes

## Declaring Encrypted Attributes

### Basic Encryption

```ruby
class User < ApplicationRecord
  encrypts :email
  encrypts :phone_number
  encrypts :ssn
end

# Transparent encryption/decryption
user = User.create(email: "user@example.com", phone_number: "555-1234")
user.email  # => "user@example.com"

# In the database, stored as encrypted JSON:
# {"p":"oq+RFYW8CucALxnJ6ccx","h":{"iv":"3nrJAIYcN1+YcGMQ","at":"JBsw7uB90yAyWbQ8E3krjg=="}}
```

### Non-deterministic Encryption (Default)

By default, encrypts the same value differently each time (different initialization vectors):

```ruby
class Article < ApplicationRecord
  encrypts :title
end

# Same title encrypts to different ciphertexts
article1 = Article.create(title: "Secret")
article2 = Article.create(title: "Secret")
# article1.ciphertext_for(:title) != article2.ciphertext_for(:title)

# Cannot query encrypted non-deterministic fields
Article.where(title: "Secret")  # Won't find the records
```

**Use when**: Content is written once and rarely queried by value (passwords, health records)

### Deterministic Encryption

Use the same initialization vector to produce consistent ciphertexts for the same plaintext:

```ruby
class Person < ApplicationRecord
  encrypts :email, deterministic: true
end

# Same email always encrypts to the same value
person = Person.create(email: "alice@example.com")
Person.find_by(email: "alice@example.com")  # Works!

# Querying is possible
Person.find_by_email("alice@example.com")  # Finds the person
```

**Use when**: Need to query or enforce uniqueness on encrypted fields (emails, usernames, employee IDs)

### Case Handling with Deterministic Encryption

#### Downcase Option

Converts to lowercase before encryption (loses original case):

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true, downcase: true
end

user = User.create(email: "Alice@EXAMPLE.COM")
user.email  # => "alice@example.com"

# Case-insensitive queries work
User.find_by(email: "ALICE@EXAMPLE.COM")  # Found
```

#### Ignore Case Option

Preserves original case for display but queries are case-insensitive:

```ruby
class Label < ApplicationRecord
  encrypts :name, deterministic: true, ignore_case: true
end

# Requires an additional column to store the original case
# Migration:
# add_column :labels, :original_name, :string
```

## Querying Encrypted Data

### Where Conditions

Hash conditions with deterministic encryption:

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true
end

# Single value
User.where(email: "user@example.com")

# Multiple values
User.where(email: ["user1@example.com", "user2@example.com"])

# Using primary key syntax
User.where(User.primary_key => [[1], [2]])
```

### Important: find_by vs find

The `id` parameter in `find_by` queries a model's `:id` attribute, not the primary key:

```ruby
class User < ApplicationRecord
  self.primary_key = [:shop_id, :id]
  encrypts :email, deterministic: true
end

# DON'T: Uses :id attribute, not composite primary key
User.find_by(id: 5)

# DO: Uses the encrypted field for querying
User.find_by(email: "user@example.com")
```

## Storage Considerations

Encrypted data takes more space due to Base64 encoding and metadata. Estimate storage needs:

### Column Size Guidelines

For short text (ASCII):
- Original: `string(50)` → Encrypted: `string(255)` (overhead: 255 bytes)

For non-Western alphabets:
- Original: `string(50)` → Encrypted: `string(200)` (4x multiplier, 255 byte max overhead)

For long text:
- Original: `text` → Encrypted: `text` (negligible overhead)

### Migration Example

```ruby
class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, limit: 510        # Double normal size
      t.string :phone, limit: 510        # Double normal size
      t.text :medical_notes              # Text for longer content
      t.timestamps
    end
  end
end
```

Compression is enabled by default (up to 30% savings for larger payloads).

## Advanced Options

### Compression Control

Disable compression if needed:

```ruby
class Article < ApplicationRecord
  encrypts :content, compress: false
end
```

Custom compression algorithm:

```ruby
require "zstd-ruby"

module ZstdCompressor
  def self.deflate(data)
    Zstd.compress(data)
  end

  def self.inflate(data)
    Zstd.decompress(data)
  end
end

class User < ApplicationRecord
  encrypts :bio, compressor: ZstdCompressor
end

# Or globally
config.active_record.encryption.compressor = ZstdCompressor
```

### Serialized Attributes

Encrypt attributes that are already serialized:

```ruby
class Article < ApplicationRecord
  # Order matters: serialize first, then encrypt
  serialize :metadata, type: Hash
  encrypts :metadata
end

article = Article.create(metadata: { views: 100, likes: 50 })
```

### Action Text with Encryption

```ruby
class Message < ApplicationRecord
  has_rich_text :content, encrypted: true
end

# Encrypted rich text fixtures go in:
# fixtures/action_text/encrypted_rich_texts.yml
```

### Encoding

By default, deterministic encryption forces UTF-8 encoding for consistent output:

```ruby
# Default: UTF-8 enforced
config.active_record.encryption.forced_encoding_for_deterministic_encryption = Encoding::UTF_8

# Custom encoding
config.active_record.encryption.forced_encoding_for_deterministic_encryption = Encoding::US_ASCII

# Disable forcing (preserve original encoding)
config.active_record.encryption.forced_encoding_for_deterministic_encryption = nil
```

## Uniqueness and Validation

### Unique Validations

Works with deterministic encryption:

```ruby
class Person < ApplicationRecord
  validates :email, uniqueness: true
  encrypts :email, deterministic: true
end

# Case-insensitive uniqueness requires downcase or ignore_case
class User < ApplicationRecord
  validates :email, uniqueness: true
  encrypts :email, deterministic: true, downcase: true
end
```

### Unique Indexes

Ensure indexes are on the encrypted column:

```ruby
# Migration
create_table :users do |t|
  t.string :email
  t.timestamps
end

add_index :users, :email, unique: true

# Model
class User < ApplicationRecord
  encrypts :email, deterministic: true
end
```

## Decryption and API Access

### Explicit Decryption

For when you need the plaintext:

```ruby
user = User.first
user.decrypt  # Decrypt all encryptable attributes in-place

# Check if attribute is encrypted
user.encrypted_attribute?(:email)  # => true

# Get the ciphertext
ciphertext = user.ciphertext_for(:email)
```

### Encryption in Tests

Enable automatic fixture encryption for tests:

```ruby
# config/environments/test.rb
Rails.application.configure do
  config.active_record.encryption.encrypt_fixtures = true
end
```

With this enabled, fixture values are automatically encrypted:

```yaml
# test/fixtures/users.yml
alice:
  email: alice@example.com  # Plain text in fixture
  name: Alice
```

## Data Migration and Rotation

### Support Unencrypted Data During Migration

For transitioning from unencrypted to encrypted:

```ruby
# config/application.rb
config.active_record.encryption.support_unencrypted_data = true
config.active_record.encryption.extend_queries = true
```

This allows:
- Reading unencrypted attributes without errors
- Querying both encrypted and unencrypted values
- Only recommended during migration period

### Key Rotation

Support multiple keys to enable key rotation:

```yaml
active_record_encryption:
  primary_key:
    - a1cc4d7b9f420e40a337b9e68c5ecec6  # Old key (can decrypt)
    - bc17e7b413fd4720716a7633027f8cc4  # New key (encrypts new data)
  key_derivation_salt: a3226b97b3b2f8372d1fc6d497a0c0d3
```

**Note**: Key rotation is not supported for deterministic encryption since changing keys breaks queryability.

### Previous Encryption Schemes

Handle attributes encrypted with different schemes:

```ruby
class Article < ApplicationRecord
  encrypts :title, deterministic: true, previous: { deterministic: false }
end
```

Enable extended queries to support transitioning between schemes:

```ruby
config.active_record.encryption.extend_queries = true
```

## Encryption Contexts

### Disable Encryption for Debugging

Useful in Rails console to examine ciphertexts:

```ruby
ActiveRecord::Encryption.without_encryption do
  user = User.first
  user.email  # Returns ciphertext JSON
end
```

### Protect Encrypted Data

Prevent accidental overwrites of encrypted data:

```ruby
ActiveRecord::Encryption.protecting_encrypted_data do
  # Reads return ciphertext
  # Writes raise an error if trying to overwrite encrypted data
  user = User.first
  user.save!  # Raises if encrypted attributes changed
end
```

## Parameter Filtering

Encrypted attributes are automatically filtered from logs:

```ruby
# Instead of: Parameters: {"email"=>"user@example.com"}
# You see: Parameters: {"email"=>"[FILTERED]"}
```

Disable auto-filtering if needed:

```ruby
# config/application.rb
config.active_record.encryption.add_to_filter_parameters = false
```

Exclude specific attributes from filtering:

```ruby
config.active_record.encryption.excluded_from_filter_parameters = [:catchphrase]
```

## Best Practices

1. **Use deterministic only when needed**: Non-deterministic is more secure; only use deterministic for queryable fields
2. **Store encryption keys separately**: Use environment variables or secure vaults, never commit keys
3. **Plan for key rotation**: Build key rotation into your security strategy
4. **Column sizing**: Account for Base64 overhead when defining column limits
5. **Test encryption**: Include encryption setup in test fixtures configuration
6. **Monitor performance**: Encryption/decryption has CPU overhead
7. **Compression consideration**: Enable compression for long text; disable if payloads are small
