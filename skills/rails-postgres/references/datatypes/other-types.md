# Other PostgreSQL Types

## Bytea (Binary Data)

```ruby
class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.binary :payload
      t.string :filename
      t.timestamps
    end
  end
end

class Document < ApplicationRecord
end

# Usage
data = File.read(Rails.root + 'tmp/output.pdf')
Document.create payload: data

document = Document.first
File.write('output.pdf', document.payload)
```

## Hstore (Key-Value Store)

```ruby
class CreateProfiles < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'hstore'
    
    create_table :profiles do |t|
      t.hstore :settings
      t.timestamps
    end
  end
end

class Profile < ApplicationRecord
end

# Usage
Profile.create(settings: { color: 'blue', resolution: '800x600' })

profile = Profile.first
profile.settings['color']  # => 'blue'

# Query
Profile.where("settings -> 'color' = ?", 'blue')
Profile.where("settings ? ?", 'color')  # Has key
```

## Network Address Types

```ruby
class CreateDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :devices do |t|
      t.inet :ip
      t.cidr :network
      t.macaddr :address
      t.timestamps
    end
  end
end

class Device < ApplicationRecord
end

# Usage
device = Device.create(
  ip: '192.168.1.12',
  network: '192.168.2.0/24',
  address: '32:01:16:6d:05:ef'
)

device.ip      # => #<IPAddr: IPv4:192.168.1.12/255.255.255.255>
device.network # => #<IPAddr: IPv4:192.168.2.0/255.255.255.0>

# Query
Device.where("ip << ?", '192.168.1.0/24')  # Contained by
```

## Intervals

```ruby
class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.interval :duration
      t.timestamps
    end
  end
end

class Event < ApplicationRecord
end

# Usage
Event.create(duration: 2.days)

event = Event.first
event.duration # => 2 days
event.duration.in_hours  # Convert to hours
```

## Geometric Types

```ruby
class CreateLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :locations do |t|
      t.point :coordinates  # (x, y)
      t.line :boundary
      t.box :area
      t.circle :radius
      t.timestamps
    end
  end
end
```

## Composite Types

```ruby
class CreateContacts < ActiveRecord::Migration[7.1]
  def change
    execute <<-SQL
      CREATE TYPE full_address AS (
        street VARCHAR(90),
        city VARCHAR(90),
        country VARCHAR(90)
      );
    SQL
    
    create_table :contacts do |t|
      t.column :address, :full_address
      t.timestamps
    end
  end
end

class Contact < ApplicationRecord
end

# Usage
Contact.create address: "(123 Main St, New York, USA)"

contact = Contact.first
contact.address # => "(123 Main St, New York, USA)"
```

## Bit String Types

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.column :settings, 'bit(8)'
      t.timestamps
    end
  end
end

class User < ApplicationRecord
end

# Usage
User.create settings: '01010011'

user = User.first
user.settings  # => '01010011'
user.settings = '0xAF'
user.settings  # => '10101111'
```
