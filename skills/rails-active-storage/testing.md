# Testing Active Storage

This guide covers testing file uploads, attachments, and Active Storage functionality in your Rails test suite.

## Test Configuration

### Configure Disk Service for Tests

```yaml
# config/storage/test.yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

# Override cloud services
amazon:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

google:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>
```

Or in environment config:

```ruby
# config/environments/test.rb
config.active_storage.service = :test
config.active_job.queue_adapter = :inline  # Process jobs immediately
```

## File Fixtures

Store test files in `test/fixtures/files/`:

```
test/fixtures/files/
  avatar.png
  document.pdf
  video.mp4
```

### System Tests

```ruby
# test/system/user_avatar_test.rb
require "application_system_test_case"

class UserAvatarTest < ApplicationSystemTestCase
  test "uploading an avatar" do
    visit new_user_path

    fill_in "Name", with: "John Doe"
    attach_file "Avatar", Rails.root.join("test/fixtures/files/avatar.png")

    click_button "Create User"

    user = User.last
    assert user.avatar.attached?
    assert_equal "avatar.png", user.avatar.filename.to_s
  end

  def after_teardown
    super
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
  end
end
```

### Integration Tests

```ruby
# test/integration/user_profile_test.rb
require "test_helper"

class UserProfileTest < ActionDispatch::IntegrationTest
  test "can upload and view avatar" do
    post user_path, params: {
      user: {
        name: "Jane Doe",
        avatar: fixture_file_upload("avatar.png", "image/png")
      }
    }

    user = User.last
    assert user.avatar.attached?
    assert_equal "image/png", user.avatar.content_type

    get user_path(user)
    assert_response :success
  end

  def after_teardown
    super
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
  end
end
```

## Unit Tests

### Test Model Validations

```ruby
# test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "avatar must be an image" do
    user = User.new(
      name: "John",
      email: "john@example.com"
    )

    user.avatar.attach(
      io: StringIO.new("not an image"),
      filename: "file.txt",
      content_type: "text/plain"
    )

    assert_not user.valid?
    assert user.errors[:avatar].present?
  end

  test "avatar size must be less than 5MB" do
    user = users(:john)

    large_file = Tempfile.new(["image", ".jpg"], binary: true)
    large_file.write("x" * 10.megabytes)
    large_file.rewind

    user.avatar.attach(
      io: large_file,
      filename: "large.jpg",
      content_type: "image/jpeg"
    )

    assert_not user.valid?
  end

  test "avatar is required" do
    user = User.new(name: "John")
    assert_not user.valid?
    assert user.errors[:avatar].present?
  end
end
```

## Controller Tests

### Test File Upload

```ruby
# test/controllers/users_controller_test.rb
require "test_helper"

class UsersControllerTest < ActionController::TestCase
  test "create user with avatar" do
    assert_difference("User.count") do
      post :create, params: {
        user: {
          name: "John Doe",
          email: "john@example.com",
          avatar: fixture_file_upload("avatar.png", "image/png")
        }
      }
    end

    user = User.last
    assert user.avatar.attached?
  end

  test "create user without avatar fails" do
    user = User.new(name: "John")
    assert_not user.valid?
  end
end
```

### Test File Download

```ruby
test "download avatar" do
  user = users(:john)

  get :show, params: { id: user.id }
  assert_response :success

  # Test avatar URL is present
  assert_select "img[src*='avatar']"
end
```

## Fixture Setup

### Add Attachments to Fixtures

```yaml
# test/fixtures/active_storage/blobs.yml
john_avatar_blob: <%= ActiveStorage::FixtureSet.blob filename: "john.png", service_name: "test" %>

jane_avatar_blob: <%= ActiveStorage::FixtureSet.blob filename: "jane.jpg", service_name: "test" %>
```

```yaml
# test/fixtures/active_storage/attachments.yml
john_avatar:
  name: avatar
  record: john (User)
  blob: john_avatar_blob

jane_avatar:
  name: avatar
  record: jane (User)
  blob: jane_avatar_blob
```

Place actual files in `test/fixtures/files/`:

```bash
cp /path/to/john.png test/fixtures/files/
cp /path/to/jane.jpg test/fixtures/files/
```

### Use Fixtures in Tests

```ruby
class UserTest < ActiveSupport::TestCase
  test "john has avatar" do
    john = users(:john)
    assert john.avatar.attached?
    assert_equal "john.png", john.avatar.filename.to_s
  end

  test "avatar content is available" do
    john = users(:john)
    content = john.avatar.download
    assert_not_nil content
    assert content.length > 0
  end
end
```

### Cleanup Fixtures

```ruby
# test/test_helper.rb
require "minitest/autorun"

Minitest.after_run do
  FileUtils.rm_rf(ActiveStorage::Blob.services.fetch(:test_fixtures).root)
end
```

## Testing with Factories

Use FactoryBot for cleaner test data:

```ruby
# test/factories/users.rb
FactoryBot.define do
  factory :user do
    name { "John Doe" }
    email { "john@example.com" }

    factory :user_with_avatar do
      after(:create) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
          filename: "avatar.png",
          content_type: "image/png"
        )
      end
    end

    factory :user_with_multiple_images do
      after(:create) do |user|
        3.times do |n|
          user.images.attach(
            io: File.open(Rails.root.join("test/fixtures/files/image#{n}.jpg")),
            filename: "image#{n}.jpg",
            content_type: "image/jpeg"
          )
        end
      end
    end
  end
end
```

Usage:

```ruby
# Create user without avatar
user = create(:user)

# Create user with avatar
user = create(:user_with_avatar)

# Create user with multiple images
user = create(:user_with_multiple_images)
```

## Testing Variants

### Test Image Variant Generation

```ruby
test "avatar variants are generated" do
  user = users(:john)
  
  # Lazy-loaded variant
  thumb_variant = user.avatar.variant(:thumb)
  assert_not_nil thumb_variant

  # Process variant
  processed = thumb_variant.processed
  assert_not_nil processed.url
end

test "custom transformation works" do
  user = users(:john)
  
  variant = user.avatar.variant(resize_to_limit: [200, 200])
  assert_not_nil variant
end
```

## Testing Querying

### Test Model Queries

```ruby
test "find users with avatars" do
  user_with_avatar = users(:john)
  user_without_avatar = User.create!(name: "Jane", email: "jane@example.com")

  users_with_avatars = User.joins(:avatar_attachment).distinct
  
  assert_includes users_with_avatars, user_with_avatar
  assert_not_includes users_with_avatars, user_without_avatar
end

test "find by attachment content type" do
  png_user = users(:john)  # png avatar
  
  png_users = User.joins(:avatar_blob)
                   .where(active_storage_blobs: { content_type: "image/png" })

  assert_includes png_users, png_user
end
```

## Cleanup After Tests

### System & Integration Tests

```ruby
# test/application_system_test_case.rb
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  def after_teardown
    super
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
  end

  # For parallel tests
  parallelize_setup do |i|
    ActiveStorage::Blob.service.root = "#{ActiveStorage::Blob.service.root}-#{i}"
  end
end
```

### Inline Active Job for Tests

```ruby
# config/environments/test.rb
config.active_job.queue_adapter = :inline
```

This ensures background jobs (like file analysis) execute immediately in tests.

## Testing Error Cases

### Test Missing File

```ruby
test "handle missing file gracefully" do
  user = users(:john)
  
  # Delete actual file from disk
  File.delete(user.avatar.key_path)
  
  assert_raises ActiveStorage::FileNotFoundError do
    user.avatar.download
  end
end
```

### Test Upload Failure

```ruby
test "handle upload failure" do
  user = User.new(name: "John")
  
  # Simulate upload error
  allow_any_instance_of(ActiveStorage::Service)
    .to receive(:upload).and_raise("Upload failed")
  
  assert_raises RuntimeError do
    user.avatar.attach(io: StringIO.new("content"), filename: "test.txt")
  end
end
```

## Troubleshooting

### Files Not Cleaning Up

```bash
rm -rf tmp/storage
```

### Parallel Test Issues

Configure separate directories:

```ruby
# config/environments/test.rb
ActiveStorage::Blob.service.root = Rails.root.join("tmp/storage_#{ENV['TEST_ENV_NUMBER']}")
```

### Fixture Files Not Found

```ruby
# Ensure paths are correct
file_path = Rails.root.join("test/fixtures/files/avatar.png")
assert file_path.exist?, "Test file not found at #{file_path}"
```
