# Testing Active Jobs

## Overview

Testing Active Jobs ensures your background workers behave correctly. Rails provides testing helpers to verify job enqueuing and execution without actually running the jobs asynchronously.

## Testing Job Enqueuing

### Basic Enqueue Test

```ruby
require 'test_helper'

class UserWelcomeJobTest < ActiveJob::TestCase
  def test_job_enqueued_on_create_account
    assert_enqueued_with(job: UserWelcomeJob) do
      User.create(email: 'user@example.com')
    end
  end
end
```

### Verify Job Queue

```ruby
class SendNotificationJobTest < ActiveJob::TestCase
  def test_notification_queued_on_priority_queue
    assert_enqueued_with(job: SendNotificationJob, queue: 'notifications') do
      Notification.create(user_id: 1, message: 'Test')
    end
  end
end
```

### Check Job Arguments

```ruby
class ProcessImportJobTest < ActiveJob::TestCase
  def test_import_job_enqueued_with_correct_args
    assert_enqueued_with(
      job: ProcessImportJob,
      args: [import_id, { format: 'csv' }]
    ) do
      import = Import.create(file: 'data.csv')
    end
  end
end
```

### Assert No Jobs Enqueued

```ruby
class UserTest < ActiveJob::TestCase
  def test_no_email_for_inactive_users
    assert_no_enqueued_jobs do
      User.create(email: 'inactive@example.com', active: false)
    end
  end
  
  def test_email_only_for_verified_users
    assert_no_enqueued_with(job: SendWelcomeEmailJob) do
      User.create(email: 'unverified@example.com', verified: false)
    end
  end
end
```

## Testing Job Execution

### Perform Job Inline

```ruby
class SendEmailJobTest < ActiveJob::TestCase
  def test_email_sent_when_job_performed
    perform_enqueued_jobs do
      SendEmailJob.perform_later(user_id)
    end
    
    assert_equal 1, ActionMailer::Base.deliveries.count
  end
end
```

### Execute Specific Job

```ruby
class ProcessDataJobTest < ActiveJob::TestCase
  def test_data_processed_correctly
    job = ProcessDataJob.new
    job.perform(data_id)
    
    data = Data.find(data_id)
    assert data.processed?
  end
end
```

### Test with Job Callbacks

```ruby
class CallbackJobTest < ActiveJob::TestCase
  def test_before_enqueue_callback_prevents_invalid_jobs
    user = User.create(email: 'user@example.com')
    user.destroy  # User is now deleted
    
    assert_no_enqueued_jobs do
      SendWelcomeJob.perform_later(user.id)
    end
  end
  
  def test_after_perform_callback_runs
    perform_enqueued_jobs do
      NotificationJob.perform_later(notification_id)
    end
    
    notification = Notification.find(notification_id)
    assert notification.sent?
  end
end
```

## Advanced Testing Patterns

### Test with Exceptions

```ruby
class ErrorHandlingJobTest < ActiveJob::TestCase
  def test_job_retried_on_timeout
    job = UnstableAPIJob.new
    
    # Simulate timeout on first attempt
    error_count = 0
    allow_any_instance_of(APIClient).to receive(:call) do
      error_count += 1
      raise Timeout::Error if error_count == 1
      { status: 'success' }
    end
    
    perform_enqueued_jobs do
      UnstableAPIJob.perform_later(api_id)
    end
    
    assert_equal 2, error_count  # Called twice: once failed, once succeeded
  end
end
```

### Test Job Continuations

```ruby
class WorkflowJobTest < ActiveJob::TestCase
  def test_continuation_steps_execute_in_sequence
    perform_enqueued_jobs do
      WorkflowJob.perform_later(workflow_id)
    end
    
    workflow = Workflow.find(workflow_id)
    assert workflow.step1_complete?
    assert workflow.step2_complete?
    assert workflow.step3_complete?
  end
end
```

### Test with Global ID

```ruby
class ProcessUserJobTest < ActiveJob::TestCase
  def test_job_with_global_id_argument
    user = User.create(email: 'test@example.com')
    
    assert_enqueued_with(job: ProcessUserJob, args: [user]) do
      ProcessUserJob.perform_later(user)
    end
    
    perform_enqueued_jobs
    
    user.reload
    assert user.processed?
  end
end
```

## RSpec Testing

### RSpec Syntax

```ruby
require 'rails_helper'

RSpec.describe SendEmailJob, type: :job do
  describe '#perform' do
    it 'enqueues the job' do
      expect {
        SendEmailJob.perform_later(user_id)
      }.to have_enqueued_job(SendEmailJob).with(user_id)
    end
    
    it 'sends email when performed' do
      expect {
        perform_enqueued_jobs { SendEmailJob.perform_later(user_id) }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
    
    it 'handles invalid user gracefully' do
      expect {
        perform_enqueued_jobs { SendEmailJob.perform_later(-1) }
      }.not_to raise_error
    end
  end
  
  describe 'callbacks' do
    it 'prevents enqueuing for deleted users' do
      user = create(:user)
      user.delete
      
      expect {
        SendEmailJob.perform_later(user.id)
      }.not_to have_enqueued_job
    end
  end
end
```

## Testing with Solid Queue

### Job Persistence Test

```ruby
class SolidQueuePersistenceTest < ActiveJob::TestCase
  def test_job_persists_in_solid_queue
    queue_size_before = SolidQueue::Job.count
    
    SendEmailJob.perform_later(user_id)
    
    queue_size_after = SolidQueue::Job.count
    assert_equal queue_size_before + 1, queue_size_after
  end
  
  def test_job_removed_after_execution
    SendEmailJob.perform_later(user_id)
    
    assert_equal 1, SolidQueue::Job.count
    
    perform_enqueued_jobs
    
    assert_equal 0, SolidQueue::Job.count
  end
end
```

## Best Practices

1. **Test enqueuing separately from execution**: Verify jobs are enqueued with correct arguments
2. **Mock external services**: Don't call real APIs or send real emails in tests
3. **Test error scenarios**: Verify retry and discard behavior
4. **Use fixtures or factories**: Create test data consistently
5. **Test callbacks**: Ensure before/after/around callbacks work correctly
6. **Verify queue assignment**: Test that jobs go to the correct queue
7. **Document async behavior**: Add comments explaining expected async behavior

## Common Assertions

| Assertion | Purpose |
|-----------|---------|
| `assert_enqueued_with` | Verify job was enqueued with specific arguments |
| `assert_enqueued_jobs` | Verify correct number of jobs were enqueued |
| `assert_no_enqueued_jobs` | Verify no jobs were enqueued |
| `perform_enqueued_jobs` | Execute all enqueued jobs |
| `perform_enqueued_jobs(only:)` | Execute only specific job classes |

## See Also

- [Job Definition](../job-basics/job-definition.md) for job structure
- [Error Handling](../advanced-features/error-handling.md) for exception testing
