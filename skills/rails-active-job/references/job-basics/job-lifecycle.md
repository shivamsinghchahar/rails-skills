# Active Job Lifecycle

## Job Lifecycle Overview

Understanding the lifecycle of an Active Job helps you implement proper error handling, callbacks, and monitoring strategies.

## Key Lifecycle Phases

### 1. Job Definition
When a job class is defined, it inherits from `ApplicationJob` (which inherits from `ActiveJob::Base`).

```ruby
class UserWelcomeMailer < ApplicationJob
  queue_as :mailers
  
  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_later
  end
end
```

### 2. Job Enqueuing
The job is enqueued when called with `perform_later` or `perform_all_later`.

```ruby
# Single job
UserWelcomeMailer.perform_later(user.id)

# Multiple jobs (bulk enqueue)
UserWelcomeMailer.perform_all_later(user_ids.map { |id| [id] })
```

### 3. Serialization
Job arguments are serialized before storage using GlobalID or custom serializers.

### 4. Queue Storage
The job is stored in the configured backend (Solid Queue, Sidekiq, etc.).

### 5. Worker Pickup
A worker process dequeues the job based on queue priority and availability.

### 6. Deserialization
Job arguments are deserialized back into their original form.

### 7. Execution
The `perform` method is called with deserialized arguments.

### 8. Completion or Failure
- **Success**: Job completes and is removed from queue
- **Failure**: Depends on exception handling configuration (`retry_on`, `discard_on`, etc.)

## Lifecycle Callbacks

Active Job provides callbacks at various points in the lifecycle:

### Enqueue Callbacks
```ruby
class PushNotificationJob < ApplicationJob
  before_enqueue do
    # Perform checks before job is queued
    if user.deleted?
      throw :abort  # Prevents enqueuing
    end
  end
  
  around_enqueue do |job, block|
    # Wrap enqueue operation
    logger.info "Enqueueing #{job.class.name}"
    block.call
    logger.info "Enqueued successfully"
  end
  
  after_enqueue do
    # Perform cleanup or logging after enqueue
    logger.info "Job #{job_id} enqueued"
  end
end
```

### Perform Callbacks
```ruby
class DataProcessingJob < ApplicationJob
  before_perform do
    logger.info "Starting data processing"
  end
  
  around_perform do |job, block|
    time = Time.current
    block.call
    logger.info "Completed in #{Time.current - time}s"
  end
  
  after_perform do
    logger.info "Data processing completed"
  end
end
```

### Discard Callback
```ruby
class APICallJob < ApplicationJob
  discard_on StandardError
  
  after_discard do |job, exception|
    # Perform cleanup when job is discarded
    ExceptionNotifier.notify(exception)
  end
end
```

## Exception Handling in Lifecycle

See [error-handling.md](../advanced-features/error-handling.md) for detailed exception handling strategies.

## Best Practices

1. **Keep callbacks lightweight** - Heavy operations should be in the `perform` method
2. **Use `before_enqueue` for validation** - Prevent invalid jobs from being queued
3. **Use `around_perform` for timing and logging** - Track job execution duration
4. **Log important state transitions** - Aid debugging and monitoring
5. **Use `after_discard` for cleanup** - Ensure resources are released
