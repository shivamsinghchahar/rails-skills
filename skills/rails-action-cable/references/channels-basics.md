# Channels and Subscriptions

Channels encapsulate logical units of work, similar to controllers in traditional Rails. Each channel handles a specific aspect of real-time communication.

## Creating Channels

Generate a new channel:

```bash
rails generate channel chat
```

This creates:
- `app/channels/chat_channel.rb`
- `app/javascript/channels/chat_channel.js`

## Basic Channel Structure

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  # Called when consumer subscribes
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  # Called when consumer unsubscribes
  def unsubscribed
    # Cleanup, stop streaming, etc.
  end

  # Called when client sends data
  def receive(data)
    # Handle incoming message
  end

  # Action that can be called from the client
  def send_message(data)
    ActionCable.server.broadcast("chat_#{params[:room]}", {
      message: data['text'],
      user: current_user.name
    })
  end
end
```

## Subscriptions

### From the Client

```javascript
// Simple subscription
consumer.subscriptions.create("ChatChannel")

// With parameters
consumer.subscriptions.create({ channel: "ChatChannel", room: "lobby" })

// With callbacks
consumer.subscriptions.create({ channel: "ChatChannel", room: "lobby" }, {
  initialized() {
    // Called when subscription is created
  },

  connected() {
    // Called when connected to channel on server
  },

  disconnected() {
    // Called when disconnected (refresh, leaving page)
  },

  rejected() {
    // Called if subscription rejected on server
  },

  received(data) {
    // Called when server broadcasts data
    console.log(data)
  }
})
```

### Multiple Subscriptions

Subscribe to multiple channels:

```javascript
// Multiple subscriptions to same channel
const room1 = consumer.subscriptions.create({ channel: "ChatChannel", room: "1" })
const room2 = consumer.subscriptions.create({ channel: "ChatChannel", room: "2" })

// Multiple different channels
const chat = consumer.subscriptions.create("ChatChannel")
const notifications = consumer.subscriptions.create("NotificationChannel")
```

## Channel Parameters

### Passing Parameters from Client

```javascript
consumer.subscriptions.create({ 
  channel: "ChatChannel", 
  room: "lobby",
  mode: "public"
})
```

### Accessing in Channel

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    room = params[:room]        # "lobby"
    mode = params[:mode]        # "public"
  end
end
```

### Validating Parameters

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    reject_subscription unless valid_room?
    stream_from "chat_#{params[:room]}"
  end

  private

  def valid_room?
    Room.exists?(params[:room])
  end
end
```

## Sending Data to Client

### Via Streams (Broadcasting)

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_global"
  end
end

# Server broadcasts to all subscribers
ActionCable.server.broadcast("chat_global", {
  type: "message",
  body: "Hello everyone"
})
```

### Direct to Subscriber

```ruby
class ChatChannel < ApplicationCable::Channel
  def get_status
    # Called from client, responds directly
    transmit({ status: "online" })
  end
end
```

### Using Stream_for (Model-Based)

```ruby
class PostsChannel < ApplicationCable::Channel
  def subscribed
    @post = Post.find(params[:id])
    stream_for @post
  end
end

# In controller or job
PostsChannel.broadcast_to(@post, { 
  comment_count: @post.comments.count 
})
```

## Handling Incoming Messages

### The receive Method

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  def receive(data)
    # data is a hash from client
    # { "message" => "Hello" }
    
    ActionCable.server.broadcast("chat_#{params[:room]}", {
      user: current_user.name,
      body: data['message'],
      timestamp: Time.current
    })
  end
end
```

### Custom Actions

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  def send_message(data)
    # Custom action called from client
    message = Message.create(
      room_id: params[:room],
      user: current_user,
      body: data['body']
    )
    
    ActionCable.server.broadcast("chat_#{params[:room]}", message)
  end

  def set_typing(data)
    # Indicate user is typing
    ActionCable.server.broadcast("chat_#{params[:room]}", {
      type: 'typing',
      user_id: current_user.id,
      typing: data['typing']
    })
  end
end
```

Calling from client:

```javascript
chatChannel.perform('send_message', { body: 'Hello' })
chatChannel.perform('set_typing', { typing: true })
```

## Channel Callbacks

Execute code at key lifecycle points:

```ruby
class ChatChannel < ApplicationCable::Channel
  before_subscribe :check_room_access
  after_subscribe :notify_room_of_join
  before_unsubscribe :log_departure
  after_unsubscribe :notify_room_of_leave

  private

  def check_room_access
    reject_subscription unless can_access_room?
  end

  def notify_room_of_join
    ActionCable.server.broadcast("chat_#{params[:room]}", {
      type: 'user_joined',
      user: current_user.name
    })
  end

  def log_departure
    Rails.logger.info "User #{current_user.id} leaving room #{params[:room]}"
  end

  def notify_room_of_leave
    ActionCable.server.broadcast("chat_#{params[:room]}", {
      type: 'user_left',
      user: current_user.name
    })
  end

  def can_access_room?
    Room.find_by(id: params[:room])&.accessible_by?(current_user)
  end
end
```

## Exception Handling

Handle errors in channels:

```ruby
class ChatChannel < ApplicationCable::Channel
  rescue_from 'StandardError', with: :report_error
  rescue_from 'MyCustomError', with: :deliver_error_message

  def send_message(data)
    # May raise MyCustomError
  end

  private

  def report_error(e)
    Rails.logger.error("Chat channel error: #{e.message}")
    SomeExternalBugtrackingService.notify(e)
  end

  def deliver_error_message(e)
    transmit(error: e.message)
  end
end
```

## Unsubscribing

### From Server

Reject or disconnect specific subscriptions:

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    unless authorized?
      reject_subscription
    else
      stream_from "chat_#{params[:room]}"
    end
  end

  def unsubscribed
    # Cleanup when user leaves channel
    user_leaves_room(params[:room], current_user)
  end
end
```

### From Client

```javascript
subscription.unsubscribe()
```

## Parent Channel Class

```ruby
# app/channels/application_cable/channel.rb
module ApplicationCable
  class Channel < ActionCable::Channel::Base
    # Shared methods for all channels
    
    def ensure_authenticated
      reject_subscription unless current_user
    end

    def current_room
      @current_room ||= Room.find_by(id: params[:room_id])
    end

    def can_access_room?
      current_room&.members&.include?(current_user)
    end
  end
end
```

## Best Practices

1. **Validate Parameters** — Always validate `params` in `subscribed`
2. **Authorize Access** — Check permissions before streaming
3. **Clean Up** — Use `unsubscribed` to clean up resources
4. **Specific Channels** — Create focused channels, not monolithic ones
5. **Document Actions** — Document what each action does and expects
6. **Handle Errors** — Use `rescue_from` for error handling
7. **Use Stream_for for Models** — Prefer `stream_for` when channel relates to a model
8. **Set Parameters Clearly** — Require specific params, not optional ones
