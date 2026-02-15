# RSpec Setup and Structure

## Configuration

RSpec configuration file (`spec/rails_helper.rb`):

```ruby
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../config/environment', __dir__)

abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  
  # Include request helpers
  config.include Rails.application.routes.url_helpers
  
  # Use FactoryBot
  config.include FactoryBot::Syntax::Methods
end
```

## Basic Structure

```ruby
RSpec.describe User, type: :model do
  # Grouping related tests
  describe 'validations' do
    it 'validates presence of email' do
      user = User.new(email: nil)
      expect(user).not_to be_valid
    end
  end
  
  # Context for setup variations
  context 'when user is admin' do
    before { @user = create(:user, :admin) }
    
    it 'allows certain actions' do
      expect(@user).to be_admin
    end
  end
end
```

## describe vs context

- `describe`: Groups related behavior (often top-level)
- `context`: Groups variations/scenarios of behavior

```ruby
RSpec.describe Post do
  describe '#publish!' do
    context 'when post is valid' do
      it 'publishes the post' do
        # test
      end
    end
    
    context 'when post is invalid' do
      it 'raises an error' do
        # test
      end
    end
  end
end
```

## Common Matchers

```ruby
# Truthiness
expect(value).to be_truthy
expect(value).to be_falsy
expect(value).to be_nil

# Equality
expect(value).to eq(expected)
expect(value).to eql(expected)
expect(value).to equal(expected)

# Collections
expect([1, 2, 3]).to include(2)
expect([1, 2, 3]).to contain_exactly(3, 1, 2)

# Strings
expect(string).to match(/pattern/)
expect(string).to start_with('Hello')
expect(string).to end_with('World')

# Comparison
expect(5).to be > 3
expect(5).to be < 10
expect(5).to be_between(0, 10)

# Range
expect(5).to be_in(0..10)

# Type
expect(value).to be_an_instance_of(String)
expect(value).to be_a(String)

# Exceptions
expect { code }.to raise_error(StandardError)
expect { code }.to raise_error(StandardError, 'message')

# Changes
expect { user.save }.to change(User, :count).by(1)
expect { user.update(name: 'New') }.to change(user, :name).from('Old').to('New')
```

## Hooks

Setup and teardown:

```ruby
RSpec.describe User do
  before(:all) do
    # Runs once before all examples
  end
  
  before(:each) do
    # Runs before each example (also called with :before)
    @user = create(:user)
  end
  
  after(:each) do
    # Runs after each example
  end
  
  after(:all) do
    # Runs once after all examples
  end
end
```

## Skipping Tests

```ruby
it 'does something' do
  # test
end

it 'skips this test', :skip do
  # test
end

it 'marks as pending' do
  pending 'Feature not implemented yet'
  # code
end

xit 'skipped with xit' do
  # test
end
```
