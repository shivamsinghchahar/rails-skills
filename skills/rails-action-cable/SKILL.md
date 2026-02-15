---
name: rails-action-cable
description: Master Action Cable for real-time WebSocket communication in Rails. Use when building real-time features like live notifications, chat, presence tracking, collaborative editing, or live data updates. Covers connections, channels, broadcasting, subscriptions, and testing.
---

# Action Cable: Real-Time WebSocket Communication

Action Cable seamlessly integrates WebSockets with Rails, enabling real-time features written in Ruby. It's a full-stack solution providing both client-side JavaScript and server-side Ruby frameworks for instant, bidirectional communication.

## When to Use Action Cable

- **Live Chat & Messaging**: Real-time message delivery and presence
- **Notifications**: Instant push notifications to connected users
- **Presence Tracking**: Show online status, active users, typing indicators
- **Live Data Updates**: Real-time feeds, dashboards, collaborative editing
- **Multiplayer Features**: Gaming, shared workspaces, synchronized state
- **Activity Streams**: Live activity feeds and live updates
- **Form Collaboration**: Real-time form input sharing and validation

## Core Concepts

Action Cable introduces three key architectural layers:

1. **Connections** — WebSocket handshake and authentication
2. **Channels** — Logical units of work (similar to controllers)
3. **Pub/Sub Broadcasting** — Message routing from server to subscribers

## Quick Start

### 1. Generate a Channel

```bash
rails generate channel chat
```

This creates:
- `app/channels/chat_channel.rb` — Server-side channel
- `app/javascript/channels/chat_channel.js` — Client-side subscription

### 2. Define the Server Channel

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end

  def receive(data)
    ActionCable.server.broadcast("chat_#{params[:room]}", {
      sent_by: current_user.name,
      body: data['message']
    })
  end
end
```

### 3. Create Client Subscription

```javascript
// app/javascript/channels/chat_channel.js
import consumer from "./consumer"

consumer.subscriptions.create({ channel: "ChatChannel", room: "lobby" }, {
  connected() {
    console.log("Connected to chat room")
  },

  received(data) {
    console.log(`${data.sent_by}: ${data.body}`)
  }
})
```

### 4. Send a Message

```javascript
const subscription = consumer.subscriptions.subscriptions[0]
subscription.send({ message: "Hello, World!" })
```

## Architecture Overview

### Server-Side

- **ApplicationCable::Connection** — Authenticates WebSocket, identifies user
- **ApplicationCable::Channel** — Parent class for all channels
- **Specific Channels** — ChatChannel, NotificationChannel, etc.
- **Broadcasting** — Send messages to channels

### Client-Side

- **Consumer** — Establishes WebSocket connection
- **Subscriptions** — Connect to channels, handle received messages
- **Performing Actions** — Call remote methods on the server channel

## Main Topics

### Connections & Authentication

Set up secure WebSocket connections with user identification:

- [Connection Setup Guide](references/connection-setup.md) — Authentication, cookies, session handling, error handling

### Channels & Subscriptions

Create channels and handle client subscriptions:

- [Channels & Subscriptions Basics](references/channels-basics.md) — Channel creation, subscriptions, callbacks, unsubscribing

### Streaming & Broadcasting

Route messages to the right subscribers:

- [Streaming & Broadcasting Guide](references/streaming-broadcasting.md) — stream_from, stream_for, broadcasting patterns, real-time updates

### Client-Side Integration

Build responsive real-time interfaces:

- [Client-Side Integration](references/client-side-integration.md) — Consumer setup, subscriptions, event handling, error recovery

### Testing Action Cable

Ensure your real-time features work correctly:

- [Testing Guide](references/testing.md) — Connection tests, channel tests, broadcast assertions, mocking

### Real-World Examples

Complete examples of common patterns:

- [Examples & Patterns](references/examples.md) — Chat, notifications, presence tracking, collaborative editing

## Configuration

### config/cable.yml

Action Cable requires a subscription adapter:

```yaml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: redis
  url: redis://localhost:6379/1
  channel_prefix: myapp_production
```

Available adapters:
- **async** — In-process (development/test only)
- **redis** — Distributed pub/sub (production recommended)
- **postgres** — Database-backed (alternative to Redis)
- **solid_cable** — Database adapter built into Rails

### config/environments/production.rb

```ruby
config.action_cable.allowed_request_origins = ['https://example.com']
config.action_cable.disable_request_forgery_protection = false
```

## Common Patterns

### Pattern 1: Broadcast from Model

Trigger broadcasts from Active Record callbacks:

```ruby
class Message < ApplicationRecord
  after_create :broadcast_message

  private
  def broadcast_message
    ChatChannel.broadcast_to(@room, {
      id: id,
      user: user.name,
      body: body,
      created_at: created_at
    })
  end
end
```

### Pattern 2: Broadcast from Job

Broadcast from background jobs:

```ruby
class NotificationJob < ApplicationJob
  def perform(user_id, message)
    user = User.find(user_id)
    NotificationChannel.broadcast_to(user, {
      title: "New notification",
      body: message
    })
  end
end
```

### Pattern 3: User-Specific Streams

Stream data to individual users:

```ruby
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end

# Broadcast to specific user:
NotificationChannel.broadcast_to(current_user, data)
```

### Pattern 4: Room-Based Streams

Stream to all users in a context (room, project, etc.):

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find(params[:room_id])
    stream_for @room
  end
end

# Broadcast to room:
ChatChannel.broadcast_to(@room, message)
```

## Best Practices

1. **Authentication First** — Always verify user identity in `connect` before allowing subscriptions
2. **Authorize Subscriptions** — Check permissions when handling `subscribed`
3. **Handle Disconnections** — Implement cleanup in `unsubscribed` callbacks
4. **Use Typed Parameters** — Always cast and validate incoming `params` and data
5. **Limit Message Size** — Keep broadcasts small to avoid performance issues
6. **Graceful Degradation** — Build apps that work without real-time (progressive enhancement)
7. **Test Thoroughly** — Test connection, subscription, and broadcast scenarios
8. **Monitor Connections** — Track active connections and memory usage in production
9. **Use Specific Channels** — Create focused channels rather than monolithic ones
10. **Document Channel API** — Clearly document what each channel does and what messages it sends

## Production Deployment

For production, Action Cable requires:

1. **Subscription Adapter** — Use Redis or PostgreSQL (not async)
2. **HTTPS/WSS** — Use secure WebSocket (`wss://`) in production
3. **Multiple Servers** — Run standalone cable server(s) separate from app servers
4. **Worker Pool** — Configure appropriate worker pool size
5. **Database Connections** — Ensure sufficient database connections for worker pool

```bash
# Run standalone cable server
bundle exec puma cable/config.ru -p 28080
```

## See Also

- [Testing Action Cable](references/testing.md)
- [Full Examples](references/examples.md)
- [Official Rails Guide](https://guides.rubyonrails.org/action_cable_overview.html)
