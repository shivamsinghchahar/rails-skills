# Streaming and Broadcasting

Streams are the mechanism by which channels route published content (broadcasts) to their subscribers.

## Stream Types

### 1. stream_from (String-based)

Stream from a named broadcasting:

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
  end
end

# From anywhere in your app, broadcast to all subscribers
ActionCable.server.broadcast("chat_lobby", { message: "Hello" })
```

### 2. stream_for (Model-based)

Stream based on Active Record model:

```ruby
class PostsChannel < ApplicationCable::Channel
  def subscribed
    @post = Post.find(params[:id])
    stream_for @post
  end
end

# Broadcasts to all subscribed to this post
PostsChannel.broadcast_to(@post, { 
  comment: comment,
  user: comment.user.name 
})
```

The broadcasting name is automatically generated from the model's GlobalID.

### 3. Multiple Streams

Subscribe to multiple streams:

```ruby
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    @user = current_user
    stream_for @user              # User-specific notifications
    stream_from "announcements"   # Global announcements
  end
end
```

## Broadcasting Patterns

### Direct Broadcasting

Send data to all subscribers of a stream:

```ruby
# Simple broadcast
ActionCable.server.broadcast("chat_room_1", {
  type: "message",
  body: "Hello there"
})

# With timestamp
ActionCable.server.broadcast("chat_room_1", {
  message: "New post published",
  timestamp: Time.current.iso8601,
  post_id: post.id
})
```

### Model-Based Broadcasting

```ruby
# After creating a message
message = Message.create(body: 'Hello', room: room)
ChatChannel.broadcast_to(room, message)

# After updating a post
@post.update(title: 'New Title')
PostsChannel.broadcast_to(@post, @post)
```

### Broadcasting from Models

Use callbacks to broadcast changes:

```ruby
class Comment < ApplicationRecord
  belongs_to :post
  
  after_create :broadcast_comment
  after_update :broadcast_comment_update
  after_destroy :broadcast_comment_delete

  private

  def broadcast_comment
    CommentsChannel.broadcast_to(
      post,
      { type: 'comment_added', comment: self }
    )
  end

  def broadcast_comment_update
    CommentsChannel.broadcast_to(
      post,
      { type: 'comment_updated', comment: self }
    )
  end

  def broadcast_comment_delete
    CommentsChannel.broadcast_to(
      post,
      { type: 'comment_deleted', id: self.id }
    )
  end
end
```

### Broadcasting from Jobs

```ruby
class NotificationJob < ApplicationJob
  def perform(user_id, message)
    user = User.find(user_id)
    NotificationChannel.broadcast_to(user, {
      title: "Notification",
      body: message
    })
  end
end
```

### Broadcasting from Controllers

```ruby
class MessagesController < ApplicationController
  def create
    @message = Message.new(message_params)
    
    if @message.save
      MessageChannel.broadcast_to(
        @message.conversation,
        { type: 'message_created', message: @message }
      )
      
      head :created
    else
      head :bad_request
    end
  end

  private

  def message_params
    params.require(:message).permit(:body)
  end
end
```

## Subscription Streaming

### Stream from Multiple Sources

```ruby
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    @user = current_user
    
    # Stream user's own updates
    stream_for @user
    
    # Stream organization-wide updates
    stream_for @user.organization
    
    # Stream team-specific updates
    @user.teams.each do |team|
      stream_for team
    end
    
    # Stream global announcements
    stream_from "announcements"
  end
end
```

### Conditional Streaming

```ruby
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    @document = Document.find(params[:id])
    
    unless authorized?
      reject_subscription
      return
    end
    
    stream_for @document
    
    # Also stream comments if user is collaborator
    if @document.collaborators.include?(current_user)
      stream_for @document, coder: ActiveSupport::JSON
    end
  end

  private

  def authorized?
    @document.readable_by?(current_user)
  end
end
```

## Real-Time Data Patterns

### Real-Time Counter Updates

```ruby
# In model
class Post < ApplicationRecord
  has_many :likes
  
  after_save :broadcast_stats

  def broadcast_stats
    PostsChannel.broadcast_to(self, {
      type: 'stats_updated',
      likes_count: likes.count,
      views_count: views_count
    })
  end
end
```

### Real-Time Presence Tracking

```ruby
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    @room = Room.find(params[:room_id])
    stream_for @room
    
    # Notify others this user is here
    notify_presence_change('online')
  end

  def unsubscribed
    notify_presence_change('offline')
  end

  private

  def notify_presence_change(status)
    PresenceChannel.broadcast_to(@room, {
      type: 'presence_changed',
      user: current_user,
      status: status
    })
  end
end
```

### Real-Time Form Updates

```ruby
class DocumentChannel < ApplicationCable::Channel
  def subscribed
    @document = Document.find(params[:id])
    stream_for @document
  end

  def update_field(data)
    field = data['field']
    value = data['value']
    
    @document.update(field => value)
    
    DocumentChannel.broadcast_to(@document, {
      type: 'field_updated',
      field: field,
      value: value,
      user: current_user.name
    })
  end
end
```

## Efficient Broadcasting

### Avoid Overbroadcasting

```ruby
# Bad: Too frequent updates
Post.all.each { |p| PostsChannel.broadcast_to(p, p) }

# Good: Only what changed
updated_posts.each { |p| PostsChannel.broadcast_to(p, p) }
```

### Payload Size

Keep broadcasts small:

```ruby
# Bad: Entire associations
ChatChannel.broadcast_to(room, {
  user: user.as_json(include: [:profile, :settings]),
  message: message
})

# Good: Only needed data
ChatChannel.broadcast_to(room, {
  user_id: user.id,
  user_name: user.name,
  message: message.body,
  created_at: message.created_at
})
```

### Selective Broadcasting

```ruby
class MessageChannel < ApplicationCable::Channel
  def subscribed
    @conversation = Conversation.find(params[:id])
    stream_for @conversation
  end

  def create_message(data)
    message = Message.create(
      conversation: @conversation,
      user: current_user,
      body: data['body']
    )
    
    # Only broadcast if message is valid
    if message.persisted?
      MessageChannel.broadcast_to(@conversation, {
        id: message.id,
        user_name: message.user.name,
        body: message.body,
        timestamp: message.created_at.iso8601
      })
    end
  end
end
```

## Stop Streaming

Stop streaming while still subscribed:

```ruby
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_global"
  end

  def mute_room
    stop_stream_from "chat_global"
  end

  def unmute_room
    stream_from "chat_global"
  end
end
```

## Testing Broadcasts

```ruby
require "test_helper"

class ChatChannelTest < ActionCable::Channel::TestCase
  test "broadcasts message to room" do
    subscribe(room: "1")
    
    assert_broadcast_on("chat_1", { type: "message" }) do
      ChatChannel.broadcast_to(
        "chat_1",
        { type: "message", body: "Hello" }
      )
    end
  end
end
```
