# Job Patterns

## Priority Job Patterns

```ruby
class CriticalEmailJob < ApplicationJob
  queue_as :critical  # Higher priority queue
  
  def perform(user_id)
    user = User.find(user_id)
    UserMailer.critical_alert(user).deliver_now
  end
end

class ReportEmailJob < ApplicationJob
  queue_as :default
  
  def perform(report_id)
    report = Report.find(report_id)
    ReportMailer.send(report).deliver_now
  end
end

class BackupJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    # Long-running backup
  end
end
```

## Chainable Jobs

```ruby
class DataPipelineJob < ApplicationJob
  def perform(data_id)
    data = Data.find(data_id)
    data.update(status: 'processing')
    
    # Process
    result = ProcessDataService.call(data)
    
    # Chain next job
    if result.success?
      EnrichDataJob.perform_later(data.id)
    else
      NotifyFailureJob.perform_later(data.id, result.errors)
    end
  end
end

class EnrichDataJob < ApplicationJob
  def perform(data_id)
    data = Data.find(data_id)
    data.update(status: 'enriching')
    
    # Enrich
    EnrichmentService.call(data)
    
    # Next step
    ExportDataJob.perform_later(data.id)
  end
end

class ExportDataJob < ApplicationJob
  def perform(data_id)
    data = Data.find(data_id)
    data.update(status: 'exporting')
    
    # Export
    ExportService.call(data)
    data.update(status: 'complete')
  end
end
```

## Progress Tracking

```ruby
class LongRunningJob < ApplicationJob
  def perform(id)
    record = Record.find(id)
    record.update(job_status: 'started', progress: 0)
    
    items = record.items
    total = items.count
    
    items.each_with_index do |item, index|
      process_item(item)
      
      progress = ((index + 1).to_f / total * 100).round
      record.update(progress:)
    end
    
    record.update(job_status: 'completed', progress: 100)
  end
end

# Client side
def job_progress
  @record = Record.find(params[:id])
  render json: { progress: @record.progress, status: @record.job_status }
end
```

## Bulk Operations

```ruby
class BulkEmailJob < ApplicationJob
  queue_as :batch
  
  def perform(user_ids)
    User.where(id: user_ids).find_each do |user|
      UserMailer.notification(user).deliver_now
    end
  end
end

# Split large batches
class SplitBulkEmailJob < ApplicationJob
  BATCH_SIZE = 100
  
  def perform(user_ids)
    user_ids.each_slice(BATCH_SIZE) do |slice|
      ProcessBatchJob.perform_later(slice)
    end
  end
end
```

## Conditional Job Enqueueing

```ruby
class OrderJob < ApplicationJob
  def perform(order_id)
    order = Order.find(order_id)
    
    # Only email if enabled in preferences
    UserMailer.order_confirmation(order.user).deliver_later if order.user.email_notifications?
    
    # Only SMS if urgent
    SMSNotifier.send(order.user, message) if order.urgent?
    
    # Chain analytics if analytics enabled
    TrackOrderJob.perform_later(order.id) if ENV['ANALYTICS_ENABLED']
  end
end
```

## Testing Jobs

```ruby
require 'rails_helper'

RSpec.describe SendEmailJob, type: :job do
  include ActiveJob::TestHelper
  
  let(:user) { create(:user) }
  
  describe '#perform_later' do
    it 'enqueues job' do
      expect {
        SendEmailJob.perform_later(user.id)
      }.to have_enqueued_job(SendEmailJob)
        .with(user.id)
        .on_queue('default')
    end
  end
  
  describe '#perform' do
    it 'sends email' do
      expect {
        SendEmailJob.perform_now(user.id)
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
    
    it 'handles missing user' do
      expect {
        SendEmailJob.perform_now(999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```
