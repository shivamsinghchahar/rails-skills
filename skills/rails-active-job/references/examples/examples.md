# Job Examples

## Email Jobs

```ruby
class SendWelcomeEmailJob < ApplicationJob
  queue_as :default
  
  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
  end
end

class SendNewsletterJob < ApplicationJob
  queue_as :batch
  
  def perform(newsletter_id)
    newsletter = Newsletter.find(newsletter_id)
    subscribers = User.where(newsletter_enabled: true)
    
    subscribers.find_each do |user|
      SendNewsletterEmailJob.perform_later(user.id, newsletter.id)
    end
  end
end

class SendNewsletterEmailJob < ApplicationJob
  retry_on(StandardError, wait: 5.seconds, attempts: 3)
  queue_as :default
  
  def perform(user_id, newsletter_id)
    user = User.find(user_id)
    newsletter = Newsletter.find(newsletter_id)
    UserMailer.newsletter(user, newsletter).deliver_now
  end
end
```

## Data Processing Jobs

```ruby
class ImportCSVJob < ApplicationJob
  queue_as :batch
  retry_on(IOError, wait: 10.seconds)
  discard_on(ArgumentError)
  
  def perform(file_path)
    File.open(file_path) do |file|
      CSV.each_row(file, headers: true) do |row|
        ImportRowJob.perform_later(row.to_h)
      end
    end
    
    File.delete(file_path)
  end
end

class ImportRowJob < ApplicationJob
  def perform(row_data)
    record = Record.create!(row_data)
    EnrichRecordJob.perform_later(record.id)
  end
end

class EnrichRecordJob < ApplicationJob
  def perform(record_id)
    record = Record.find(record_id)
    enrichment = ExternalService.enrich(record)
    record.update(enrichment_data: enrichment)
  end
end
```

## Scheduled/Recurring Jobs

```ruby
class DailyReportJob < ApplicationJob
  queue_as :critical
  
  def perform
    yesterday = Date.yesterday
    report = Report.generate(start_date: yesterday, end_date: yesterday)
    ReportMailer.daily_report(report).deliver_now
  end
end

class WeeklyCleanupJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    # Delete old sessions
    Session.where('created_at < ?', 30.days.ago).delete_all
    
    # Archive old logs
    Log.where('created_at < ?', 90.days.ago).delete_all
    
    # Cleanup temporary files
    TempFile.delete_expired
  end
end

class MonthlyBillingJob < ApplicationJob
  queue_as :critical
  retry_on(PaymentGatewayError, wait: 1.hour, attempts: 5)
  
  def perform
    Subscription.active.find_each do |subscription|
      ChargeSubscriptionJob.perform_later(subscription.id)
    end
  end
end

class ChargeSubscriptionJob < ApplicationJob
  def perform(subscription_id)
    subscription = Subscription.find(subscription_id)
    
    charge = PaymentGateway.charge(
      amount: subscription.amount,
      customer_id: subscription.user.payment_customer_id
    )
    
    subscription.charges.create!(
      amount: charge.amount,
      transaction_id: charge.id
    )
  end
end
```

## Analytics/Tracking Jobs

```ruby
class TrackEventJob < ApplicationJob
  queue_as :low_priority
  
  def perform(user_id, event_type, data = {})
    user = User.find(user_id)
    
    AnalyticsService.track(
      user_id: user.id,
      event: event_type,
      properties: data,
      timestamp: Time.current
    )
  end
end

# Usage
class PostsController < ApplicationController
  def view
    @post = Post.find(params[:id])
    TrackEventJob.perform_later(current_user.id, 'post_viewed', post_id: @post.id)
  end
end
```

## Search Index Updates

```ruby
class IndexPostJob < ApplicationJob
  queue_as :batch
  
  def perform(post_id)
    post = Post.find(post_id)
    SearchIndex.index(post)
  end
end

class ReindexAllJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    Post.find_each do |post|
      IndexPostJob.perform_later(post.id)
    end
  end
end

# Usage
class Post < ApplicationRecord
  after_create { IndexPostJob.perform_later(id) }
  after_update { IndexPostJob.perform_later(id) }
  after_destroy { SearchIndex.delete(id) }
end
```

## Third-party API Sync

```ruby
class SyncUserDataJob < ApplicationJob
  retry_on(APIConnectionError, wait: 5.minutes, attempts: 3)
  discard_on(UserNotFoundError)
  
  def perform(user_id)
    user = User.find(user_id)
    
    begin
      response = ThirdPartyAPI.fetch_user(user.external_id)
      user.update(
        external_data: response.data,
        last_synced_at: Time.current
      )
    rescue ThirdPartyAPI::NotFound
      raise UserNotFoundError
    end
  end
end

# Schedule sync
class ScheduleSyncJob < ApplicationJob
  def perform
    User.where('last_synced_at < ?', 1.day.ago).pluck(:id).each do |user_id|
      SyncUserDataJob.perform_later(user_id)
    end
  end
end
```
