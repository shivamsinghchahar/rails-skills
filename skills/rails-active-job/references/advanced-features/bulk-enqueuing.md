# Bulk Enqueuing Jobs

## Overview

Bulk enqueuing allows you to enqueue multiple jobs efficiently in a single operation. This is significantly faster than enqueuing jobs individually and is useful for batch operations.

## Basic Bulk Enqueuing

Use `perform_all_later` to enqueue multiple jobs at once:

```ruby
# Array of argument arrays
job_args = [
  [user_id_1],
  [user_id_2],
  [user_id_3]
]

UserNotificationJob.perform_all_later(job_args)
```

### With Multiple Arguments

```ruby
# Each element is an array of arguments for one job
job_args = [
  [user_id_1, 'welcome'],
  [user_id_2, 'reminder'],
  [user_id_3, 'alert']
]

NotificationJob.perform_all_later(job_args)
```

## Common Use Cases

### Batch Processing Users

```ruby
class SendDailyDigestJob < ApplicationJob
  def perform(user_id)
    user = User.find(user_id)
    DigestMailer.daily(user).deliver_later
  end
end

# Send digest to 1000 users at once
user_ids = User.active.pluck(:id)
job_args = user_ids.map { |id| [id] }
SendDailyDigestJob.perform_all_later(job_args)
```

### Processing Multiple Data Items

```ruby
class ProcessReportJob < ApplicationJob
  def perform(report_id, format)
    report = Report.find(report_id)
    # Process based on format (pdf, csv, excel, etc.)
    report.generate(format)
  end
end

# Process multiple reports in different formats
job_args = [
  [report_1_id, 'pdf'],
  [report_2_id, 'csv'],
  [report_3_id, 'excel']
]
ProcessReportJob.perform_all_later(job_args)
```

### Batch Image Processing

```ruby
class OptimizeImageJob < ApplicationJob
  def perform(image_id, size)
    image = Image.find(image_id)
    image.optimize_for_size(size)
  end
end

# Generate multiple image sizes
image_id = params[:image_id]
sizes = ['thumbnail', 'medium', 'large']
job_args = sizes.map { |size| [image_id, size] }
OptimizeImageJob.perform_all_later(job_args)
```

## Performance Considerations

### Bulk Enqueue vs. Individual Enqueue

```ruby
# ❌ Slow: 1000 individual enqueues
1000.times do |i|
  EmailJob.perform_later(user_ids[i])
end

# ✅ Fast: Single bulk operation
EmailJob.perform_all_later(user_ids.map { |id| [id] })
```

**Bulk enqueuing benefits:**
- Single database transaction
- Much faster for large batches
- Reduces queue backend overhead
- Better for solid queue performance

### Chunk Large Batches

For very large batches, process in chunks to avoid memory issues:

```ruby
class SendBulkEmailsJob < ApplicationJob
  def perform
    user_ids = User.active.pluck(:id)
    chunk_size = 1000
    
    user_ids.each_slice(chunk_size) do |chunk|
      job_args = chunk.map { |id| [id] }
      EmailJob.perform_all_later(job_args)
    end
  end
end
```

## Error Handling with Bulk Enqueue

All jobs in a bulk enqueue operation share the same error handling configuration:

```ruby
class ImportDataJob < ApplicationJob
  discard_on StandardError
  retry_on Timeout::Error, wait: 10.seconds, attempts: 3
  
  def perform(record_id)
    record = Record.find(record_id)
    record.import
  end
end

# If any job fails with StandardError, it's discarded
# If any job fails with Timeout, it retries
job_args = import_ids.map { |id| [id] }
ImportDataJob.perform_all_later(job_args)
```

## Combining with Bulk Create/Update

```ruby
class ProcessImportJob < ApplicationJob
  def perform
    file = import_file
    records = parse_csv(file)
    
    # Bulk create records
    created = Record.insert_all(records, returning: [:id])
    
    # Bulk enqueue processing jobs
    job_args = created.map { |r| [r['id']] }
    ProcessRecordJob.perform_all_later(job_args)
  end
end
```

## Monitoring Bulk Operations

### Track Progress

```ruby
class ProcessBulkImportJob < ApplicationJob
  def perform(batch_id)
    batch = ImportBatch.find(batch_id)
    items = batch.items.pending
    
    total = items.count
    batch.update(total_count: total)
    
    job_args = items.map { |item| [item.id] }
    ProcessImportItemJob.perform_all_later(job_args)
  end
end

# Monitor in a separate job or controller
class MonitorImportProgressJob < ApplicationJob
  def perform(batch_id)
    batch = ImportBatch.find(batch_id)
    completed = batch.items.where(status: 'completed').count
    
    progress = (completed.to_f / batch.total_count * 100).round(2)
    puts "Import #{batch_id} progress: #{progress}%"
  end
end
```

## Best Practices

1. **Map arguments correctly**: Ensure each element is an array of arguments
2. **Use for batch operations**: Most beneficial when enqueueing 10+ jobs
3. **Chunk very large batches**: Process in manageable sizes (1000-10000 items)
4. **Monitor queue health**: Watch for queue buildup with bulk operations
5. **Consistent error handling**: All jobs share the same exception handlers
6. **Log batch information**: Track batch ID or size for debugging

## See Also

- [Job Definition](../job-basics/job-definition.md) for basic enqueuing
- [Queue Management](../queue-management/queue-setup.md) for queue configuration
- [Error Handling](../advanced-features/error-handling.md) for error strategies
