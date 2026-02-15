# Factories and Fixtures

## FactoryBot Setup

Configuration (`spec/support/factory_bot.rb`):

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

Factories file (`spec/factories/users.rb`):

```ruby
FactoryBot.define do
  factory :user do
    first_name { 'John' }
    last_name { 'Doe' }
    email { Faker::Internet.email }
    password { 'password123' }
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :inactive do
      active { false }
    end
  end
end
```

## Factory Basics

```ruby
# Create and save
user = create(:user)

# Build without saving
user = build(:user)

# Create without hitting database (attributes_for in params)
attrs = attributes_for(:user)

# Create multiple
users = create_list(:user, 3)

# With overrides
user = create(:user, email: 'custom@example.com')

# With traits
admin = create(:user, :admin)
inactive = create(:user, :inactive)

# Combine traits
user = create(:user, :admin, :inactive)
```

## Sequences and Traits

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "username#{n}" }
    
    # Traits for variations
    trait :admin do
      role { 'admin' }
    end
    
    trait :with_posts do
      after(:create) { |user| create_list(:post, 3, user: user) }
    end
  end
  
  factory :post do
    title { Faker::Lorem.sentence }
    content { Faker::Lorem.paragraph }
    user { create(:user) }
  end
  
  factory :comment do
    content { Faker::Lorem.sentence }
    user { association(:user) }
    post { association(:post) }
  end
end
```

## Associations in Factories

```ruby
factory :post do
  title { 'Post Title' }
  user { create(:user) }  # Creates a user
end

# Or
factory :post do
  title { 'Post Title' }
  user { association :user }  # Creates a user
end

# Or lazy build
factory :post do
  title { 'Post Title' }
  association :user
end

# With trait overrides
factory :post do
  title { 'Post Title' }
  association :user, :admin
end
```

## Callbacks

```ruby
factory :user do
  first_name { 'John' }
  
  after(:build) { |user| user.profile.age = 18 }
  after(:create) { |user| create(:profile, user: user) }
  before(:create) { |user| user.password_reset_token = SecureRandom.hex }
end
```

## Polymorphic Associations

```ruby
factory :comment do
  content { 'Great post!' }
  association :commentable, factory: :post
  association :user
end

# Use specific type
comment = create(:comment, commentable: create(:photo))
```
