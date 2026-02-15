# Concurrency Controls

## Overview

Concurrency controls in Active Job help manage how many workers can run simultaneously and limit overlapping execution of the same job. This prevents resource exhaustion, race conditions, and data consistency issues.

## Job Concurrency Limits

Use `limit_concurrency_to` to restrict how many instances of a job can run at the same time:

```ruby
class HeavyProcessingJob < ApplicationJob
  limit_concurrency_to 1  # Only 1 instance can run at a time
  
  def perform(data_id)
    # This job will wait if another instance is running
    data = Data.find(data_id)
    data.heavy_processing
  end
end
```

## Common Use Cases

### Database Intensive Operations

```ruby
class LargeDataMigrationJob < ApplicationJob
  limit_concurrency_to 1  # Prevent multiple migrations
  
  def perform(migration_id)
    migration = DataMigration.find(migration_id)
    migration.execute  # Could lock tables
  end
end
```

### External API Rate Limiting

```ruby
class SyncExternalDataJob < ApplicationJob
  limit_concurrency_to 2  # API allows 2 concurrent requests
  
  def perform(resource_id)
    resource = Resource.find(resource_id)
    external_data = ExternalAPI.fetch(resource)
    resource.update(data: external_data)
  end
end
```

### File System Operations

```ruby
class GenerateReportJob < ApplicationJob
  limit_concurrency_to 5  # Limit concurrent file I/O
  
  def perform(report_id)
    report = Report.find(report_id)
    report.generate_pdf  # Disk intensive
  end
end
```

### Memory Intensive Tasks

```ruby
class ProcessImageBatchJob < ApplicationJob
  limit_concurrency_to 2  # Images use significant memory
  
  def perform(batch_id)
    batch = ImageBatch.find(batch_id)
    batch.process_all_images
  end
end
```

## Concurrency Configuration

### Multiple Limits

Different job types can have different limits:

```ruby
class FastJob < ApplicationJob
  limit_concurrency_to 10  # Allow many concurrent instances
  
  def perform
    # Quick operation
  end
end

class SlowJob < ApplicationJob
  limit_concurrency_to 1  # Only one at a time
  
  def perform
    # Resource-intensive operation
  end
end
```

### With Duration

Control how long the concurrency limit is held:

```ruby
class LongRunningJob < ApplicationJob
  limit_concurrency_to 1, duration: 30.minutes
  
  def perform(task_id)
    task = Task.find(task_id)
    task.long_operation  # Could exceed 30 minutes, lock released after
  end
end
```

## Monitoring Concurrency

### Check Active Jobs

```ruby
# Count currently running jobs of a specific type
active_count = SolidQueue::Job.where(class_name: 'MyJob').count

# Get all running jobs
running_jobs = SolidQueue::Job.where('started_at IS NOT NULL')
```

### Dashboard Monitoring

```ruby
class JobMonitoringJob < ApplicationJob
  def perform
    heavy_jobs = SolidQueue::Job.where(class_name: 'HeavyProcessingJob')
    active = heavy_jobs.where('started_at IS NOT NULL').count
    
    if active > 5
      AlertService.notify("Heavy jobs at capacity: #{active} running")
    end
  end
end
```

## Best Practices

### 1. Start Conservative
```ruby
# Start with low limits and increase as needed
class ExternalSyncJob < ApplicationJob
  limit_concurrency_to 2  # Start here
  
  def perform(source_id)
    ExternalAPI.sync(source_id)
  end
end
```

### 2. Match Infrastructure
```ruby
# Align with available resources
class DatabaseOperationJob < ApplicationJob
  limit_concurrency_to 4  # Match worker pool size
  
  def perform
    # Database operation
  end
end
```

### 3. Combine with Retries
```ruby
class APICallJob < ApplicationJob
  limit_concurrency_to 3
  retry_on TimeoutError, wait: 5.seconds, attempts: 3
  
  def perform(api_id)
    ApiService.call(api_id)
  end
end
```

### 4. Document Reasoning
```ruby
class ImageProcessingJob < ApplicationJob
  # Limited to 2 because:
  # - Each image uses ~200MB memory
  # - Server has ~2GB available for jobs
  # - Need 500MB buffer for other processes
  limit_concurrency_to 2
  
  def perform(image_id)
    Image.find(image_id).process!
  end
end
```

### 5. Monitor and Adjust
```ruby
class ConcurrencyMonitorJob < ApplicationJob
  queue_as :monitoring
  
  def perform
    {
      'ProcessImageJob' => SolidQueue::Job.where(class_name: 'ProcessImageJob').count,
      'ExternalSyncJob' => SolidQueue::Job.where(class_name: 'ExternalSyncJob').count,
      'DatabaseMigrationJob' => SolidQueue::Job.where(class_name: 'DatabaseMigrationJob').count
    }.each do |job_class, count|
      Rails.logger.info("#{job_class}: #{count} running")
    end
  end
end
```

## Troubleshooting

### Jobs Stuck in Queue
If jobs aren't executing due to concurrency limits:
- Check if limit is 1 and a job is hung
- Monitor job execution times
- Increase limit if resource capacity is available

### Performance Issues
If concurrency limits cause slowdowns:
- Increase the limit if resources allow
- Profile the job to find bottlenecks
- Consider refactoring to smaller jobs

### Resource Exhaustion
If you're hitting resource limits:
- Lower the concurrency limit
- Optimize the job code
- Split large jobs into smaller chunks

## See Also

- [Job Definition](../job-basics/job-definition.md) for job structure
- [Queue Management](../queue-management/queue-setup.md) for queue configuration
- [Error Handling](../advanced-features/error-handling.md) for fault tolerance
