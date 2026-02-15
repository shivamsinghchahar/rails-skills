# Testing Action Cable

Comprehensive testing ensures real-time features work correctly and reliably.

## Connection Tests

Test authentication and connection establishment:

```ruby
require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects with valid user cookie" do
    cookies.encrypted[:user_id] = users(:john).id
    connect
    assert_equal connection.current_user, users(:john)
  end

  test "rejects connection without user" do
    assert_reject_connection { connect }
  end

  test "connects with query token" do
    connect params: { token: 'valid-token' }
    assert_equal connection.current_user, users(:john)
  end

  test "rejects invalid token" do
    assert_reject_connection { connect params: { token: 'invalid' } }
  end
end
```

## Channel Tests

Test channel subscriptions and actions:

```ruby
require "test_helper"

class ChatChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:john)
  end

  test "subscribes successfully to room" do
    subscribe(room: "lobby")
    
    assert subscription.confirmed?
    assert_has_stream "chat_lobby"
  end

  test "unsubscribes from room" do
    subscribe(room: "lobby")
    unsubscribe
    
    assert_no_stream
  end

  test "rejects subscription without room" do
    assert_no_stream_subscribed do
      subscribe
    end
  end

  test "performs send_message action" do
    subscribe(room: "lobby")
    
    assert_broadcast_on("chat_lobby", { user: "John", body: "Hello" }) do
      perform :send_message, { body: "Hello" }
    end
  end

  test "broadcasts notification on message" do
    subscribe(room: "lobby")
    
    assert_broadcasts("chat_lobby", 1) do
      perform :send_message, { body: "Test" }
    end
  end
end
```

### Channel with User

Stub connection identifiers:

```ruby
class NotificationChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for user" do
    stub_connection(current_user: users(:john))
    
    subscribe
    
    assert subscription.confirmed?
    assert_has_stream_for users(:john)
  end

  test "broadcasts notification to user" do
    stub_connection(current_user: users(:john))
    subscribe
    
    assert_broadcast_on("notification_#{users(:john).id}", { type: 'alert' }) do
      NotificationChannel.broadcast_to(users(:john), { type: 'alert' })
    end
  end
end
```

## Broadcast Assertions

### assert_broadcast_on

Test specific broadcast:

```ruby
class ProductTest < ActionCable::TestCase
  test "broadcasts status after charge" do
    product = products(:one)
    
    assert_broadcast_on("products:#{product.id}", type: "charged") do
      product.charge(account)
    end
  end
end
```

### assert_broadcasts

Count total broadcasts:

```ruby
test "broadcasts multiple updates" do
  product = products(:one)
  
  assert_broadcasts("products:#{product.id}", 2) do
    product.charge(account)
    product.notify_review
  end
end
```

### assert_no_broadcasts

Ensure no broadcasts:

```ruby
test "does not broadcast if not charged" do
  product = products(:one)
  
  assert_no_broadcasts("products:#{product.id}") do
    product.invalid_charge(account)
  end
end
```

## Testing Broadcasting from Jobs

```ruby
require "test_helper"

class NotificationJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "broadcasts notification to user" do
    user = users(:john)
    
    assert_broadcast_on(
      NotificationChannel.broadcasting_for(user),
      { title: "Hi!", body: "New message" }
    ) do
      NotificationJob.perform_now(user.id, "New message")
    end
  end
end
```

## Testing Broadcasting from Models

```ruby
class CommentTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "broadcasts comment creation" do
    post = posts(:one)
    
    assert_broadcast_on(
      CommentChannel.broadcasting_for(post),
      { type: 'comment_added' }
    ) do
      Comment.create(post: post, body: "Great post!")
    end
  end
end
```

## Testing Broadcasting from Controllers

```ruby
class MessagesControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "creates message and broadcasts" do
    conversation = conversations(:one)
    
    assert_broadcast_on("messages:#{conversation.id}") do
      post messages_url, params: {
        message: { body: "Hello", conversation_id: conversation.id }
      }
    end
  end
end
```

## Integration Tests

Test complete workflows:

```ruby
class ChatFlowTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "users can chat in real-time" do
    # User 1 logs in
    login_as users(:john)
    get chat_path(room: "lobby")
    
    # User 2 logs in separately
    post messages_path, params: { body: "Hello" }, headers: auth_headers
    
    # Verify broadcast happened
    assert_broadcast_on("chat_lobby", { body: "Hello" })
  end
end
```

## Full Channel Integration Test

```ruby
class ChatChannelIntegrationTest < ActionCable::Channel::TestCase
  test "complete chat flow" do
    # User subscribes to room
    stub_connection(current_user: users(:john))
    subscribe(room: "lobby")
    
    assert subscription.confirmed?
    assert_has_stream "chat_lobby"
    
    # User sends message
    assert_broadcast_on("chat_lobby") do
      perform :send_message, { body: "Hello" }
    end
    
    # User leaves room
    unsubscribe
    
    assert_no_stream
  end

  test "handles invalid message" do
    stub_connection(current_user: users(:john))
    subscribe(room: "lobby")
    
    # Sending empty message should not broadcast
    assert_no_broadcasts("chat_lobby") do
      perform :send_message, { body: "" }
    end
  end
end
```

## Testing Rejections

```ruby
class PrivateChannelTest < ActionCable::Channel::TestCase
  test "rejects unauthorized user" do
    stub_connection(current_user: users(:unauthorized))
    
    assert_no_stream_subscribed do
      subscribe
    end
  end

  test "accepts authorized user" do
    stub_connection(current_user: users(:authorized))
    
    subscribe
    assert_has_stream_for users(:authorized)
  end
end
```

## Testing with Fixtures

```ruby
class ChatChannelTest < ActionCable::Channel::TestCase
  test "uses fixture data" do
    user = users(:john)
    stub_connection(current_user: user)
    
    subscribe(room: "lobby")
    
    assert_equal user, connection.current_user
  end
end
```

## Client-Side Testing (JavaScript)

With `@rails/actioncable` test utilities:

```javascript
// Example using Jest
describe('ChatChannel', () => {
  let consumer
  let subscription

  beforeEach(() => {
    consumer = ActionCable.createConsumer('ws://localhost:3000/cable')
  })

  afterEach(() => {
    if (subscription) {
      subscription.unsubscribe()
    }
  })

  test('connects to channel', (done) => {
    subscription = consumer.subscriptions.create(
      { channel: 'ChatChannel', room: 'lobby' },
      {
        connected() {
          expect(subscription).toBeDefined()
          done()
        }
      }
    )
  })

  test('receives messages', (done) => {
    subscription = consumer.subscriptions.create(
      { channel: 'ChatChannel', room: 'lobby' },
      {
        received(data) {
          expect(data.body).toBe('Hello')
          done()
        }
      }
    )
  })
})
```

## Testing Tips

1. **Use stub_connection** — Mock current_user without authentication
2. **Test rejections** — Verify unauthorized subscriptions are rejected
3. **Test streams** — Verify channels stream correct data
4. **Test broadcasts** — Assert broadcast content and frequency
5. **Test cleanup** — Verify unsubscribe removes streams
6. **Use fixtures** — Reuse test data across tests
7. **Test invalid data** — Ensure malformed data is handled
8. **Test errors** — Verify rescue_from works correctly
9. **Integration tests** — Test complete user workflows
10. **Async tests** — Remember broadcasts are async, use proper assertions

## Common Testing Patterns

### Test Permission-Based Streaming

```ruby
class DocumentChannelTest < ActionCable::Channel::TestCase
  test "streams only to authorized users" do
    document = documents(:shared)
    
    # Authorized user
    stub_connection(current_user: users(:owner))
    subscribe(id: document.id)
    assert_has_stream_for document
    unsubscribe
    
    # Unauthorized user
    stub_connection(current_user: users(:stranger))
    assert_no_stream_subscribed do
      subscribe(id: document.id)
    end
  end
end
```

### Test Real-Time Data Updates

```ruby
class PostChannelTest < ActionCable::Channel::TestCase
  test "broadcasts post updates" do
    stub_connection(current_user: users(:john))
    post = posts(:one)
    subscribe(id: post.id)
    
    assert_broadcast_on(PostChannel.broadcasting_for(post)) do
      post.update(title: 'Updated')
    end
  end
end
```
