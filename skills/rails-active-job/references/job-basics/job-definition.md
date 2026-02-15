# Job Definition

## Basic Job Structure

```ruby
class SendEmailJob < ApplicationJob
  queue_as :default
  
  def perform(user_id, email_type = 'welcome')
    user = User.find(user_id)
    UserMailer.send(email_type, user).deliver_now
  end
end

# Enqueue
SendEmailJob.perform_later(user.id)
SendEmailJob.perform_later(user.id, 'newsletter')

# Execute immediately
SendEmailJob.perform_now(user.id)
```

## Job Lifecycle

```ruby
class ProcessFileJob < ApplicationJob
  queue_as :default
  
  # Before enqueue
  before_enqueue do |job|
    Rails.logger.info "Job #{job.class} queued"
  end
  
  # After enqueue
  around_enqueue do |job, block|
    start = Time.current
    block.call
    Rails.logger.info "Queued in #{Time.current - start}s"
  end
  
  # Before perform
  before_perform do |job|
    Rails.logger.info "Starting #{job.class}"
  end
  
  # After perform
  after_perform do |job|
    Rails.logger.info "Finished #{job.class}"
  end
  
  def perform(file_id)
    file = ProcessableFile.find(file_id)
    # Process file
  end
end
```

## Idempotency

Jobs must be safe to retry. Design them idempotently:

```ruby
# Bad: Not idempotent (duplicate charge)
class ChargeUserJob < ApplicationJob
  def perform(user_id, amount)
    user = User.find(user_id)
    Payment.create!(amount:, user:)  # Creates duplicate on retry
  end
end

# Good: Idempotent (checks existing payment)
class ChargeUserJob < ApplicationJob
  def perform(user_id, amount, idempotency_key)
    return if Payment.exists?(idempotency_key:)
    
    user = User.find(user_id)
    Payment.create!(amount:, user:, idempotency_key:)
  end
end

# Or use database constraints
class ChargeUserJob < ApplicationJob
  def perform(user_id, amount)
    user = User.find(user_id)
    Payment.find_or_create_by!(user:, amount:, created_date: Date.today)
  end
end
```

## Job Parameters

```ruby
class ProcessDataJob < ApplicationJob
  queue_as :default
  
  def perform(user_id, options = {})
    user = User.find(user_id)
    force_refresh = options.fetch(:force, false)
    
    # Process user data
  end
end

# Simple types (string, integer, boolean)
ProcessDataJob.perform_later(1, force: true)

# With hash
ProcessDataJob.set(wait: 1.hour).perform_later(user.id, format: 'csv')

# Complex objects - serialize to ID
class SendReportJob < ApplicationJob
  def perform(report_id)
    report = Report.find(report_id)
    ReportMailer.send(report).deliver_now
  end
end
```

## Job Data

Access job metadata:

```ruby
class TrackableJob < ApplicationJob
  def perform(user_id)
    Rails.logger.info "Job ID: #{job_id}"
    Rails.logger.info "Queued at: #{enqueued_at}"
    Rails.logger.info "Executions: #{executions}"
  end
end
```

## Discard Jobs

```ruby
class ImportDataJob < ApplicationJob
  discard_on(ActiveRecord::RecordNotFound) do |job, error|
    Rails.logger.error "Job #{job.id} discarded: #{error}"
  end
  
  def perform(data_file_id)
    file = DataFile.find(data_file_id)  # Raises if not found
    file.process
  end
end
```

## Wait and Schedule

```ruby
# Wait before executing
SendEmailJob.set(wait: 10.minutes).perform_later(user.id)

# Scheduled for specific time
SendEmailJob.set(wait_until: 1.day.from_now).perform_later(user.id)

# Multiple jobs with timing
SendEmailJob.set(wait: 1.hour).perform_later(user.id)
FollowUpEmailJob.set(wait: 3.days).perform_later(user.id)
```
