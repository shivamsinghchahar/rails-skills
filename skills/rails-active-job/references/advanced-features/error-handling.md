# Error Handling

## Exception Handling Strategies

```ruby
class SafeJob < ApplicationJob
  retry_on(Timeout::Error, wait: 10.seconds, attempts: 3)
  discard_on(ArgumentError)
  
  rescue_from(StandardError) do |error|
    Sentry.capture_exception(error, extra: { job: self.class.name })
  end
  
  def perform(id)
    begin
      # Might timeout
      fetch_data_with_timeout(id)
    rescue Timeout::Error => e
      raise  # Will trigger retry_on
    rescue ArgumentError => e
      Rails.logger.error("Invalid argument: #{e.message}")
      # Will trigger discard_on, no retry
    end
  end
end
```

## Dead Letter Queue Pattern

```ruby
class JobWithDLQ < ApplicationJob
  discard_on(StandardError) do |job, error|
    DeadLetterQueue.create!(
      job_class: job.class.name,
      job_id: job.job_id,
      error_message: error.message,
      error_backtrace: error.backtrace,
      job_params: job.arguments,
      created_at: Time.current
    )
    
    AlertingService.notify_ops("Job #{job.job_id} discarded: #{error.message}")
  end
  
  def perform(id)
    # Processing logic
  end
end

# Replay jobs from DLQ
class ReplayDLQJob < ApplicationJob
  def perform
    DeadLetterQueue.where(replayed: false).each do |dlq_entry|
      job_class = dlq_entry.job_class.constantize
      job_class.perform_later(*dlq_entry.job_params)
      dlq_entry.update(replayed: true, replayed_at: Time.current)
    end
  end
end
```

## Alerting on Failures

```ruby
class CriticalJob < ApplicationJob
  discard_on(StandardError) do |job, error|
    SlackNotifier.post(
      channel: '#alerts',
      text: "🚨 Job #{job.class} failed permanently: #{error.message}"
    )
    
    PagerDuty.trigger(
      service: 'Background Jobs',
      description: "Critical job failed: #{error.message}"
    )
  end
  
  def perform(id)
    # Critical business logic
  end
end
```

## Timeout Handling

```ruby
class TimeoutAwareJob < ApplicationJob
  queue_as :default
  
  retry_on(Timeout::Error, wait: 5.seconds, attempts: 3)
  discard_on(StandardError) do |job, error|
    Rails.logger.error "Job timeout after retries: #{error}"
  end
  
  def perform(user_id)
    Timeout.timeout(30.seconds) do
      user = User.find(user_id)
      # Long-running task
      process_user_data(user)
    end
  end
end
```

## Circuit Breaker Pattern

```ruby
class ExternalAPIJob < ApplicationJob
  retry_on(ExternalAPIError, wait: :exponentially_longer, attempts: 5)
  discard_on(CircuitBreakerOpen)
  
  def perform(record_id)
    raise CircuitBreakerOpen if ExternalAPI.circuit_breaker.open?
    
    record = Record.find(record_id)
    response = ExternalAPI.call(record)
    record.update(external_id: response.id)
  end
end

class CircuitBreaker
  def initialize(threshold = 5, timeout = 1.hour)
    @threshold = threshold
    @timeout = timeout
    @failures = 0
    @opened_at = nil
  end
  
  def open?
    @opened_at && Time.current < @opened_at + @timeout
  end
  
  def record_failure
    @failures += 1
    @opened_at = Time.current if @failures >= @threshold
  end
  
  def record_success
    @failures = 0
    @opened_at = nil
  end
end
```

## Logging and Instrumentation

```ruby
class InstrumentedJob < ApplicationJob
  def perform(id)
    start_time = Time.current
    
    begin
      Rails.logger.info "Starting job with id=#{id}"
      do_work(id)
      duration = Time.current - start_time
      
      Metrics.record('job.success', duration: duration, job: self.class.name)
      Rails.logger.info "Job completed in #{duration}s"
    rescue => error
      duration = Time.current - start_time
      Metrics.record('job.failure', duration: duration, job: self.class.name, error: error.class)
      Rails.logger.error "Job failed: #{error.message}"
      raise
    end
  end
end
```

## Idempotency Tokens

```ruby
class CreatePaymentJob < ApplicationJob
  def perform(user_id, amount, idempotency_key)
    return if Payment.exists?(idempotency_key:)
    
    user = User.find(user_id)
    payment = user.payments.create!(
      amount:,
      idempotency_key:
    )
    
    PaymentProcessor.process(payment)
  end
end

# Usage
idempotency_key = SecureRandom.uuid
CreatePaymentJob.perform_later(user.id, 99.99, idempotency_key)
```
