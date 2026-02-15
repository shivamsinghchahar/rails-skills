---
name: rails-active-job
description: Master Active Job framework for asynchronous background job processing. Use when building background workers, handling async operations, managing job queues, scheduling recurring tasks, or processing long-running operations. Covers job definition, Solid Queue backend, error handling, and advanced patterns.
---

# Active Job: Background Job Processing

Active Job is Rails' framework for declaring background jobs and processing them asynchronously. Use it to offload work from the request-response cycle, improving application responsiveness.

## When to Use Active Jobs

- **Email sending**: Async mailers to avoid request delays
- **Heavy computations**: Process data without blocking users
- **External API calls**: Retry logic for unreliable services
- **Bulk operations**: Process large datasets in the background
- **Scheduled tasks**: Recurring operations with cron jobs
- **Event processing**: Handle webhooks and event notifications
- **Cleanup tasks**: Database maintenance and data archival

## Quick Start

### Create a Job

```bash
rails generate job SendWelcomeEmail
```

### Define the Job

```ruby
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default  # Route to 'default' queue
  
  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_later
  end
end
```

### Enqueue the Job

```ruby
# Enqueue immediately
SendWelcomeEmailJob.perform_later(user.id)

# Enqueue with delay
SendWelcomeEmailJob.set(wait: 1.hour).perform_later(user.id)

# Enqueue at specific time
SendWelcomeEmailJob.set(wait_until: 2.days.from_now).perform_later(user.id)

# Enqueue multiple jobs at once
user_ids.map { |id| [id] }.then do |args|
  SendWelcomeEmailJob.perform_all_later(args)
end
```

## Job Basics

Learn fundamental job concepts and lifecycle:

- [Job Definition](references/job-basics/job-definition.md) — Job structure, configuration, perform method
- [Job Lifecycle](references/job-basics/job-lifecycle.md) — Job execution phases and callbacks
- [Job Patterns](references/job-basics/job-patterns.md) — Common implementations and best practices

## Queue Management

Configure and manage job queues:

- [Queue Setup](references/queue-management/queue-setup.md) — Solid Queue configuration, threading, queue ordering
- [Concurrency Controls](references/advanced-features/concurrency-controls.md) — Limit concurrent job execution

## Advanced Features

Master sophisticated job patterns:

- [Scheduling & Retries](references/advanced-features/scheduling-retries.md) — Recurring jobs, retry strategies, backoff
- [Error Handling](references/advanced-features/error-handling.md) — Exception handling, discard policies, dead letter queues
- [Job Continuations](references/advanced-features/job-continuations.md) — Multi-step resumable workflows (Rails 8+)
- [Bulk Enqueuing](references/advanced-features/bulk-enqueuing.md) — Efficient batch job enqueueing
- [Testing](references/advanced-features/testing.md) — Test job enqueuing and execution

## Examples

See [Real-world implementations](references/examples/examples.md) covering:
- Email notifications
- Data imports and exports
- Image processing
- External API synchronization
- Report generation
- Webhook handling

## Default Backend: Solid Queue

Rails 8+ includes Solid Queue as the default job backend. Configure in `config/solid_queue.yml`:

```yaml
production:
  queues:
    - name: default
      threads: 5
    - name: critical
      threads: 2
    - name: batch
      threads: 1
  
  workers:
    - name: worker_1
      queues: [ default, critical, batch ]
  
  scheduler:
    workers: 1
```

Solid Queue provides:
- Database-backed job storage (no additional dependencies)
- Queue ordering and priority
- Concurrency limiting
- Repeating jobs (cron-like scheduling)
- Multi-threaded workers
- Built-in error tracking

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Job** | Ruby class defining async work (inherits from ApplicationJob) |
| **Queue** | Named container for jobs (default, critical, batch, etc.) |
| **Enqueue** | Add job to queue for processing (perform_later) |
| **Worker** | Process that executes jobs from queues |
| **Retry** | Automatic job re-execution after failure |
| **Discard** | Permanently skip job after error |
| **Continuation** | Resume job execution in steps (Rails 8+) |

## Next Steps

1. Start with [Job Definition](references/job-basics/job-definition.md) to understand job structure
2. Configure [Queue Setup](references/queue-management/queue-setup.md) for your environment
3. Add [Error Handling](references/advanced-features/error-handling.md) for reliability
4. Learn [Testing](references/advanced-features/testing.md) strategies for your jobs
5. Explore [Examples](references/examples/examples.md) for your use case

## Resources

- [Rails Guides: Active Job Basics](https://guides.rubyonrails.org/active_job_basics.html)
- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [Rails API: ActiveJob](https://api.rubyonrails.org/classes/ActiveJob.html)
