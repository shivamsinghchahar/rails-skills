# Real-World Examples

Complete, practical examples of common Action Cable patterns.

## Example 1: Chat Application

Complete chat room implementation:

### Server Channel

```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find(params[:room_id])
    
    unless @room.members.include?(current_user)
      reject_subscription
      return
    end
    
    stream_for @room
    
    # Notify room members that user joined
    ChatChannel.broadcast_to(@room, {
      type: 'user_joined',
      user: current_user,
      timestamp: Time.current
    })
  end

  def unsubscribed
    # Notify room members that user left
    ChatChannel.broadcast_to(@room, {
      type: 'user_left',
      user: current_user,
      timestamp: Time.current
    })
  end

  def send_message(data)
    message = Message.create!(
      room: @room,
      user: current_user,
      body: data['body']
    )
    
    ChatChannel.broadcast_to(@room, {
      type: 'message',
      id: message.id,
      user: message.user.name,
      body: message.body,
      timestamp: message.created_at.iso8601
    })
  rescue => e
    Rails.logger.error("Chat error: #{e.message}")
    transmit({ error: 'Failed to send message' })
  end

  def set_typing(data)
    ChatChannel.broadcast_to(@room, {
      type: 'typing',
      user_id: current_user.id,
      user_name: current_user.name,
      typing: data['typing']
    })
  end
end
```

### Client JavaScript

```javascript
// app/javascript/channels/chat_channel.js
import consumer from "./consumer"

const subscription = consumer.subscriptions.create(
  { channel: "ChatChannel", room_id: document.querySelector('[data-room-id]').value },
  {
    connected() {
      console.log("Connected to chat room")
    },

    received(data) {
      switch(data.type) {
        case 'message':
          this.appendMessage(data)
          break
        case 'user_joined':
          this.showNotification(`${data.user.name} joined`)
          break
        case 'user_left':
          this.showNotification(`${data.user.name} left`)
          break
        case 'typing':
          this.showTypingIndicator(data)
          break
      }
    },

    appendMessage(data) {
      const messagesDiv = document.querySelector('[data-messages]')
      const time = new Date(data.timestamp).toLocaleTimeString()
      messagesDiv.insertAdjacentHTML('beforeend', `
        <div class="message">
          <strong>${data.user}</strong>
          <span class="time">${time}</span>
          <p>${this.escapeHtml(data.body)}</p>
        </div>
      `)
      messagesDiv.scrollTop = messagesDiv.scrollHeight
    },

    showNotification(text) {
      const notification = document.createElement('div')
      notification.className = 'notification'
      notification.textContent = text
      document.querySelector('[data-messages]').insertAdjacentElement('afterbegin', notification)
    },

    showTypingIndicator(data) {
      const indicators = document.querySelector('[data-typing]')
      indicators.innerHTML = `${data.user_name} is typing...`
      setTimeout(() => { indicators.innerHTML = '' }, 3000)
    },

    escapeHtml(text) {
      const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }
      return text.replace(/[&<>"']/g, m => map[m])
    }
  }
)

document.querySelector('[data-message-form]').addEventListener('submit', (e) => {
  e.preventDefault()
  const input = document.querySelector('[data-message-input]')
  subscription.perform('send_message', { body: input.value })
  input.value = ''
})

document.querySelector('[data-message-input]').addEventListener('input', () => {
  subscription.perform('set_typing', { typing: true })
})
```

## Example 2: Live Notifications

Deliver notifications in real-time:

### Server Channel

```ruby
# app/channels/notification_channel.rb
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end

# Broadcast a notification
NotificationChannel.broadcast_to(user, {
  type: 'notification',
  title: 'New Comment',
  body: 'Someone commented on your post',
  action_url: post_path(post)
})
```

### Trigger from Model

```ruby
class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user
  
  after_create :notify_post_author

  private

  def notify_post_author
    return if user == post.author
    
    NotificationChannel.broadcast_to(post.author, {
      type: 'new_comment',
      title: "New comment from #{user.name}",
      body: body.truncate(100),
      action_url: post_path(post)
    })
  end
end
```

### Client JavaScript

```javascript
import consumer from "./consumer"

consumer.subscriptions.create("NotificationChannel", {
  received(data) {
    this.showNotification(data)
  },

  showNotification(data) {
    if (Notification.permission === "granted") {
      new Notification(data.title, {
        body: data.body,
        icon: '/notification-icon.png',
        tag: data.type,
        requireInteraction: true
      })
    }
  }
})
```

## Example 3: Presence Tracking

Show who's online and what they're doing:

### Server Channel

```ruby
# app/channels/presence_channel.rb
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user.organization
  end
end

# Track presence in connection
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      broadcast_presence('online')
    end

    def disconnect
      broadcast_presence('offline')
    end

    private

    def broadcast_presence(status)
      PresenceChannel.broadcast_to(current_user.organization, {
        type: 'presence_changed',
        user_id: current_user.id,
        user_name: current_user.name,
        status: status,
        timestamp: Time.current
      })
    end
  end
end
```

### Client JavaScript

```javascript
import consumer from "./consumer"

const presenceMap = new Map()

consumer.subscriptions.create("PresenceChannel", {
  received(data) {
    if (data.type === 'presence_changed') {
      if (data.status === 'online') {
        presenceMap.set(data.user_id, data)
      } else {
        presenceMap.delete(data.user_id)
      }
      this.updatePresenceList()
    }
  },

  updatePresenceList() {
    const list = document.querySelector('[data-presence-list]')
    list.innerHTML = Array.from(presenceMap.values())
      .map(user => `<li class="online"><span>${user.user_name}</span></li>`)
      .join('')
  }
})
```

## Example 4: Collaborative Editing

Real-time synchronized editing:

### Server Channel

```ruby
# app/channels/document_channel.rb
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    @document = Document.find(params[:id])
    
    unless @document.editable_by?(current_user)
      reject_subscription
      return
    end
    
    stream_for @document
    
    # Notify that user is editing
    DocumentChannel.broadcast_to(@document, {
      type: 'editor_joined',
      user: current_user,
      cursor_color: current_user.avatar_color
    })
  end

  def unsubscribed
    DocumentChannel.broadcast_to(@document, {
      type: 'editor_left',
      user_id: current_user.id
    })
  end

  def update_content(data)
    # Save change
    change = DocumentChange.create!(
      document: @document,
      user: current_user,
      content: data['content'],
      version: data['version']
    )
    
    # Broadcast to all editors
    DocumentChannel.broadcast_to(@document, {
      type: 'content_changed',
      content: change.content,
      user: current_user,
      version: change.version,
      timestamp: change.created_at.iso8601
    })
  end

  def update_cursor(data)
    DocumentChannel.broadcast_to(@document, {
      type: 'cursor_moved',
      user_id: current_user.id,
      line: data['line'],
      column: data['column']
    })
  end
end
```

### Client JavaScript

```javascript
import consumer from "./consumer"

const subscription = consumer.subscriptions.create(
  { channel: "DocumentChannel", id: documentId },
  {
    received(data) {
      if (data.type === 'content_changed') {
        editor.setValue(data.content)
      } else if (data.type === 'cursor_moved') {
        this.updateRemoteCursor(data)
      } else if (data.type === 'editor_joined') {
        this.showEditorPresence(data)
      }
    },

    updateRemoteCursor(data) {
      const marker = document.querySelector(`[data-user-cursor="${data.user_id}"]`)
      if (marker) {
        marker.style.left = `${data.column * 8}px`
        marker.style.top = `${data.line * 20}px`
      }
    },

    showEditorPresence(data) {
      console.log(`${data.user.name} is editing`)
    }
  }
)

editor.addEventListener('change', () => {
  subscription.perform('update_content', {
    content: editor.getValue(),
    version: currentVersion
  })
})

editor.addEventListener('cursorActivity', () => {
  const pos = editor.getCursor()
  subscription.perform('update_cursor', {
    line: pos.line,
    column: pos.ch
  })
})
```

## Example 5: Live Dashboard

Real-time metrics and updates:

### Server

```ruby
# app/channels/dashboard_channel.rb
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end
end

# Job that updates dashboard stats
class DashboardUpdateJob < ApplicationJob
  def perform(user_id)
    user = User.find(user_id)
    stats = {
      active_sessions: calculate_active_sessions(user),
      revenue_today: calculate_revenue(user),
      pending_orders: user.orders.pending.count
    }
    
    DashboardChannel.broadcast_to(user, {
      type: 'stats_updated',
      stats: stats
    })
  end
end

# Trigger updates periodically
class ApplicationJob < ActiveJob::Base
  def self.every_minute
    set(wait: 1.minute).perform_later
  end
end
```

### Client JavaScript

```javascript
consumer.subscriptions.create("DashboardChannel", {
  received(data) {
    if (data.type === 'stats_updated') {
      this.updateDashboard(data.stats)
    }
  },

  updateDashboard(stats) {
    document.querySelector('[data-active-sessions]').textContent = stats.active_sessions
    document.querySelector('[data-revenue]').textContent = '$' + stats.revenue_today.toFixed(2)
    document.querySelector('[data-pending]').textContent = stats.pending_orders
  }
})
```

## Testing These Examples

```ruby
# test/channels/chat_channel_test.rb
class ChatChannelTest < ActionCable::Channel::TestCase
  setup do
    @user = users(:john)
    @room = rooms(:lobby)
    @room.members << @user
    stub_connection(current_user: @user)
  end

  test "broadcasts message to room" do
    subscribe(room_id: @room.id)
    
    assert_broadcast_on(ChatChannel.broadcasting_for(@room)) do
      perform :send_message, { body: "Hello" }
    end
  end

  test "notifies when user joins" do
    assert_broadcast_on(ChatChannel.broadcasting_for(@room), { type: 'user_joined' }) do
      subscribe(room_id: @room.id)
    end
  end
end
```
