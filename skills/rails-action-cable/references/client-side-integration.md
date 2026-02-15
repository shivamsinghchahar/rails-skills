# Client-Side Integration

Building responsive real-time interfaces with Action Cable's JavaScript consumer.

## Consumer Setup

### Default Consumer

Rails creates a default consumer at `app/javascript/channels/consumer.js`:

```javascript
import { createConsumer } from "@rails/actioncable"

export default createConsumer()
```

This connects to `/cable` by default (configured via `action_cable_meta_tag` in layout).

### Custom Consumer URL

```javascript
// Specify different URL
import { createConsumer } from "@rails/actioncable"

export default createConsumer('wss://example.com/cable')

// Or with dynamic URL
function getWebSocketURL() {
  const token = localStorage.getItem('auth-token')
  return `wss://example.com/cable?token=${token}`
}

export default createConsumer(getWebSocketURL())
```

### HTTPS/WSS in Production

Configure in environment file:

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.action_cable.url = "wss://example.com/cable"
end
```

Then include in layout:

```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <%= action_cable_meta_tag %>
</head>
```

## Creating Subscriptions

### Basic Subscription

```javascript
import consumer from "./consumer"

consumer.subscriptions.create("ChatChannel", {
  received(data) {
    console.log("Received:", data)
  }
})
```

### Subscription with Parameters

```javascript
consumer.subscriptions.create(
  { channel: "ChatChannel", room: "lobby" },
  {
    received(data) {
      console.log("Message:", data.body)
    }
  }
)
```

### Full Subscription Lifecycle

```javascript
consumer.subscriptions.create(
  { channel: "ChatChannel", room: "lobby" },
  {
    // Called once when subscription created
    initialized() {
      console.log("Subscription initialized")
      this.updateList = this.updateList.bind(this)
    },

    // Called when subscribed to server channel
    connected() {
      console.log("Connected to channel")
      this.requestLatestMessages()
    },

    // Called when connection drops
    disconnected() {
      console.log("Disconnected from channel")
    },

    // Called if server rejects subscription
    rejected() {
      console.log("Subscription rejected")
    },

    // Called when server broadcasts data
    received(data) {
      console.log("Received data:", data)
      this.appendMessage(data)
    },

    // Custom methods
    requestLatestMessages() {
      this.perform('get_messages', { limit: 10 })
    },

    appendMessage(data) {
      const element = document.querySelector("[data-messages]")
      element.insertAdjacentHTML("beforeend", `
        <div class="message">
          <strong>${data.user}</strong>
          <p>${data.body}</p>
        </div>
      `)
    }
  }
)
```

## Sending Data to Server

### Via Receive

Server calls `receive(data)` method:

```javascript
const subscription = consumer.subscriptions.create("ChatChannel", {
  received(data) {
    console.log(data)
  }
})

// Send to server's receive method
subscription.send({ message: "Hello" })
```

### Via Perform

Call specific action on server:

```javascript
const subscription = consumer.subscriptions.create("ChatChannel", {
  received(data) {
    console.log(data)
  }
})

// Call specific methods on server
subscription.perform('send_message', { body: 'Hello' })
subscription.perform('set_typing', { typing: true })
subscription.perform('clear_notification', { id: 123 })
```

## Managing Subscriptions

### Store Reference

```javascript
const chatSubscription = consumer.subscriptions.create(
  { channel: "ChatChannel", room: "lobby" },
  {
    received(data) {
      console.log(data)
    }
  }
)

// Later use the subscription
chatSubscription.perform('send_message', { body: 'Hi' })
chatSubscription.unsubscribe()
```

### Multiple Subscriptions

```javascript
const chat1 = consumer.subscriptions.create(
  { channel: "ChatChannel", room: "lobby" }
)
const chat2 = consumer.subscriptions.create(
  { channel: "ChatChannel", room: "random" }
)
const notifications = consumer.subscriptions.create("NotificationChannel")

// Send to all
consumer.subscriptions.subscriptions.forEach(sub => {
  sub.perform('ping')
})
```

### Unsubscribe

```javascript
const subscription = consumer.subscriptions.create("ChatChannel")

// Later
subscription.unsubscribe()
```

## Event Handling

### DOM Event Binding

```javascript
consumer.subscriptions.create("ChatChannel", {
  connected() {
    this.installBindings()
  },

  disconnected() {
    this.removeBindings()
  },

  installBindings() {
    document.addEventListener('submit', this.handleSubmit.bind(this))
    document.addEventListener('click', this.handleClick.bind(this))
  },

  removeBindings() {
    document.removeEventListener('submit', this.handleSubmit)
    document.removeEventListener('click', this.handleClick)
  },

  handleSubmit(event) {
    if (event.target.matches('[data-chat-form]')) {
      const input = event.target.querySelector('[data-message]')
      this.perform('send_message', { body: input.value })
      input.value = ''
    }
  },

  handleClick(event) {
    if (event.target.matches('[data-emoji]')) {
      this.perform('react', { emoji: event.target.dataset.emoji })
    }
  }
})
```

### Browser Events

```javascript
consumer.subscriptions.create("AppearanceChannel", {
  connected() {
    window.addEventListener('focus', this.appear.bind(this))
    window.addEventListener('blur', this.away.bind(this))
    document.addEventListener('turbo:load', this.appear.bind(this))
  },

  disconnected() {
    window.removeEventListener('focus', this.appear)
    window.removeEventListener('blur', this.away)
    document.removeEventListener('turbo:load', this.appear)
  },

  appear() {
    this.perform('appear', { status: 'online' })
  },

  away() {
    this.perform('away', { status: 'away' })
  }
})
```

## Error Handling & Recovery

### Connection Errors

```javascript
let reconnectAttempts = 0

consumer.subscriptions.create("ChatChannel", {
  connected() {
    console.log("Connected")
    reconnectAttempts = 0
  },

  disconnected() {
    console.log("Disconnected, attempting to reconnect...")
    this.scheduleReconnect()
  },

  rejected() {
    console.log("Subscription rejected")
  },

  scheduleReconnect() {
    reconnectAttempts += 1
    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000)
    
    setTimeout(() => {
      consumer.subscriptions.subscriptions = []
      this.attemptReconnection()
    }, delay)
  },

  attemptReconnection() {
    // Recreate subscription to retry
    consumer.subscriptions.create("ChatChannel")
  }
})
```

### Data Validation

```javascript
consumer.subscriptions.create("ChatChannel", {
  received(data) {
    if (this.isValidMessage(data)) {
      this.appendMessage(data)
    } else {
      console.error("Invalid message format:", data)
    }
  },

  isValidMessage(data) {
    return (
      data.id &&
      data.user_id &&
      data.body &&
      typeof data.body === 'string'
    )
  },

  appendMessage(data) {
    // Safe to use
  }
})
```

## State Management

### Storing Data

```javascript
const subscription = consumer.subscriptions.create("ChatChannel", {
  initialized() {
    this.messages = []
    this.users = new Map()
  },

  received(data) {
    if (data.type === 'message') {
      this.messages.push(data)
      this.render()
    } else if (data.type === 'user_joined') {
      this.users.set(data.user.id, data.user)
      this.updateUserList()
    }
  },

  render() {
    const list = document.querySelector('[data-messages]')
    list.innerHTML = this.messages.map(m => `
      <div class="message">
        <strong>${m.user}</strong>: ${m.body}
      </div>
    `).join('')
  },

  updateUserList() {
    const list = document.querySelector('[data-users]')
    list.innerHTML = Array.from(this.users.values()).map(u => `
      <li>${u.name}</li>
    `).join('')
  }
})
```

## Debugging

### Client-Side Logging

Enable logging:

```javascript
import * as ActionCable from '@rails/actioncable'

ActionCable.logger.enabled = true
```

Or with custom logger:

```javascript
import * as ActionCable from '@rails/actioncable'

ActionCable.logger.log = (message) => {
  console.log('[ActionCable]', message)
}
```

### Monitor Connection

```javascript
const connection = consumer.subscriptions

setInterval(() => {
  const connected = consumer.subscriptions.subscriptions.length > 0
  console.log('Connected:', connected)
}, 5000)
```

## Best Practices

1. **Always handle disconnection** — Implement `disconnected` callback
2. **Validate received data** — Check structure before using
3. **Clean up bindings** — Remove event listeners in `disconnected`
4. **Bind methods** — Use `.bind(this)` for event handlers
5. **Handle missing server** — Show error if unable to connect
6. **Retry logic** — Implement exponential backoff for reconnects
7. **Small payloads** — Keep broadcast data lean
8. **Error logging** — Log connection and data errors
9. **Secure tokens** — Pass tokens securely if needed
10. **Test offline** — Ensure app degrades gracefully offline
