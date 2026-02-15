# Scheduling and Retries

## Retry Configuration

```ruby
class ReliableJob < ApplicationJob
  queue_as :default
  
  # Default retry (5 times with exponential backoff)
  retry_on(StandardError)
  
  # Custom retry strategy
  retry_on(StandardError, wait: 5.seconds, attempts: 3)
  
  # Exponential backoff
  retry_on(StandardError, wait: :exponentially_longer, attempts: 5)
  
  # Custom wait calculation
  retry_on(StandardError, wait: :exponentially_longer) do |executions|
    executions * 2  # 2, 4, 8, 16 seconds
  end
  
  def perform(id)
    # Code that might fail
  end
end
```

## Multiple Retry Handlers

```ruby
class RobustJob < ApplicationJob
  retry_on(NetworkError, wait: 2.seconds, attempts: 3)
  retry_on(DatabaseConnectionError, wait: 10.seconds, attempts: 5)
  discard_on(InvalidDataError)  # No retry, just discard
  
  def perform(id)
    begin
      do_something(id)
    rescue NetworkError => e
      raise  # Will trigger retry_on
    rescue InvalidDataError => e
      # Handle invalid data, won't retry
    end
  end
end
```

## Recurring Jobs (Scheduled)

Use `gem 'solid_queue_recurring'` or Rails 8+ `recurring_jobs`:

```ruby
# config/recurring.yml
send_reports:
  class: SendReportsJob
  schedule: every day at 8:00 am
  
process_cleanup:
  class: CleanupOldRecordsJob
  schedule: every Monday at 2:00 pm
  
frequent_sync:
  class: SyncDataJob
  schedule: every 15 minutes
```

Or programmatically:

```ruby
# config/initializers/recurring_jobs.rb
class SendReportsJob < ApplicationJob
  def perform
    # Send reports
  end
end

SolidQueue::Scheduler.schedule(
  class_name: 'SendReportsJob',
  schedule: 'every day at 8:00 am'
)
```

## Cron Expressions

```ruby
# Every day at 2 AM
schedule: 0 2 * * *

# Every weekday at 9 AM
schedule: 0 9 * * 1-5

# Every 30 minutes
schedule: */30 * * * *

# First day of month at midnight
schedule: 0 0 1 * *

# Every quarter
schedule: 0 0 1 */3 *
```

## Wait Strategies

```ruby
class AdaptiveJob < ApplicationJob
  # Fixed wait
  retry_on(APIError, wait: 10.seconds)
  
  # Exponential backoff
  retry_on(APIError, wait: :exponentially_longer)
  
  # Polynomial backoff
  retry_on(APIError, wait: :polynomially_longer)
  
  # Custom block
  retry_on(APIError) do |executions|
    (executions + 1) * 2.seconds
  end
end
```

## Track Retry Count

```ruby
class MonitoredJob < ApplicationJob
  def perform(user_id)
    begin
      do_work(user_id)
    rescue => error
      if executions < 3
        raise error  # Retry
      else
        log_permanent_failure(user_id, error)
        # Don't retry
      end
    end
  end
  
  private
  
  def executions
    job.executions || 0
  end
end
```

## Batch Jobs

```ruby
class BatchProcessJob < ApplicationJob
  def perform(batch_id)
    batch = DataBatch.find(batch_id)
    batch.items.in_batches(of: 100).each do |items|
      items.each { |item| process_item(item) }
    end
  end
end

# Or break into multiple jobs
class ProcessBatchJob < ApplicationJob
  def perform(batch_id)
    batch = DataBatch.find(batch_id)
    batch.items.each do |item|
      ProcessItemJob.perform_later(item.id)
    end
  end
end

class ProcessItemJob < ApplicationJob
  def perform(item_id)
    item = Item.find(item_id)
    # Process single item
  end
end
```
