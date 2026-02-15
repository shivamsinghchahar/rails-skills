# Solid Queue Setup

## Configuration

Create `config/solid_queue.yml`:

```yaml
default: &default
  processes:
    - host: localhost
      queues:
        - critical
        - default
        - low_priority
  workers:
    - processes_ids:
        - '1'
      queues: critical
      threads: 4
    - processes_ids:
        - '1'
      queues: [default, low_priority]
      threads: 2

development:
  <<: *default
  processes:
    - host: localhost
      queues:
        - '*'

test:
  adapter: inline
  
production:
  <<: *default
  processes:
    - host: app.example.com
      queue_size: 1000
```

## Queue Assignment

```ruby
class CriticalJob < ApplicationJob
  queue_as :critical
end

class DefaultJob < ApplicationJob
  queue_as :default  # Default if not specified
end

class LowPriorityJob < ApplicationJob
  queue_as :low_priority
end

# Dynamic queue assignment
class DynamicJob < ApplicationJob
  queue_as do
    current_user.premium? ? :critical : :default
  end
end
```

## Start Solid Queue

```bash
# Start worker
bundle exec solid_queue:start

# In Procfile.dev
web: bin/rails server
solid_queue: bundle exec solid_queue:start

# Start with specific workers
bundle exec solid_queue:start --from-config config/solid_queue.yml
```

## Configuration Options

```ruby
# config/initializers/solid_queue.rb
Solid::Queue.error_handler = ->(error, job, options) do
  Sentry.capture_exception(error, extra: { job: job, options: options })
end

Solid::Queue.logger = Logger.new("log/solid_queue.log")
```

## Metrics and Monitoring

```ruby
# Check queue sizes
SolidQueue::Queues.active.map { |q| [q.name, q.size] }

# Job statistics
SolidQueue::Job.where(status: 'finished').count
SolidQueue::Job.where(status: 'failed').count

# Monitor in web UI (requires gem 'mission_control-jobs')
# Visit /solid_queue for dashboard
```

## Testing

```ruby
# config/environments/test.rb
config.active_job.queue_adapter = :inline  # Execute synchronously
config.active_job.queue_adapter = :test    # For testing with perform_enqueued_jobs

# Or per test
RSpec.describe SendEmailJob do
  it 'sends email' do
    expect {
      SendEmailJob.perform_later(user.id)
    }.to have_enqueued_job(SendEmailJob)
  end
end
```
