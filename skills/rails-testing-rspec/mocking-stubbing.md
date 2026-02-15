# Mocking and Stubbing

## Stubbing Methods

```ruby
# Stub a method
user = create(:user)
allow(user).to receive(:full_name).and_return('Stubbed Name')
expect(user.full_name).to eq('Stubbed Name')

# Stub with arguments
allow(user).to receive(:authenticate).with('password').and_return(true)
expect(user.authenticate('password')).to be_truthy

# Stub multiple methods
allow(user).to receive(:admin?).and_return(true)
allow(user).to receive(:email).and_return('admin@example.com')

# Stub to raise error
allow(user).to receive(:save).and_raise(StandardError, 'Database error')
expect { user.save }.to raise_error(StandardError)
```

## Instance Doubles

```ruby
# Create a double without a real object
user = instance_double(User)
allow(user).to receive(:email).and_return('test@example.com')
expect(user.email).to eq('test@example.com')

# Strict double verifies method exists
user = instance_double('User', email: 'test@example.com')

# Verify method signature
user = instance_double(User, save: true)
```

## Class Doubles

```ruby
# Stub class methods
allow(User).to receive(:find).with(1).and_return(user)
expect(User.find(1)).to eq(user)

# Stub all
allow(User).to receive(:all).and_return([user1, user2])
```

## Mocks

Test that methods are called:

```ruby
user = create(:user)

# Verify method is called
expect(user).to receive(:save).and_call_original
user.save

# Verify method is called with arguments
expect(user).to receive(:authenticate).with('password')
user.authenticate('password')

# Verify method is called N times
expect(user).to receive(:reload).exactly(2).times
user.reload
user.reload

# Never called
expect(user).not_to receive(:destroy)
# code that shouldn't call destroy
```

## Spies

Track calls without changing behavior:

```ruby
user = create(:user)

# Spy on method calls
allow(user).to receive(:send_email).and_call_original
user.send_email

# Verify it was called
expect(user).to have_received(:send_email)

# Verify with arguments
expect(user).to have_received(:send_email).with('test@example.com')

# Verify call count
expect(user).to have_received(:send_email).twice
```

## External Service Stubbing

```ruby
# Stub HTTP requests
stub_request(:get, 'https://api.example.com/users/1')
  .to_return(status: 200, body: '{"id": 1, "name": "John"}')

# Test the code
response = HTTPClient.get('https://api.example.com/users/1')
expect(response.status).to eq(200)

# Or use VCR for recording/replaying
VCR.use_cassette('fetch_user') do
  response = User.fetch_from_api(1)
  expect(response.name).to eq('John')
end
```

## Stubbing Time

```ruby
# Freeze time
allow(Time).to receive(:now).and_return(Time.new(2024, 1, 1))

# Or use timecop gem
Timecop.freeze(Time.new(2024, 1, 1)) do
  user.created_at # Will use frozen time
end
```
