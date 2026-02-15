# Testing Examples

## Model Spec (User)

```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
    it { is_expected.to have_one(:profile) }
  end
  
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_length_of(:first_name).is_at_least(2) }
  end
  
  describe '#full_name' do
    it 'returns concatenated names' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end
  
  describe '.active' do
    let!(:active_user) { create(:user, active: true) }
    let!(:inactive_user) { create(:user, active: false) }
    
    it 'returns only active users' do
      expect(User.active).to contain_exactly(active_user)
    end
  end
  
  describe '#admin?' do
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }
    
    it 'returns true for admins' do
      expect(admin.admin?).to be_truthy
    end
    
    it 'returns false for regular users' do
      expect(user.admin?).to be_falsy
    end
  end
end
```

## Controller Spec (Posts)

```ruby
require 'rails_helper'

RSpec.describe PostsController, type: :request do
  let(:user) { create(:user) }
  let(:post) { create(:post, user: user) }
  let(:other_user) { create(:user) }
  
  describe 'GET /posts' do
    it 'lists all posts' do
      create_list(:post, 3)
      get posts_path
      expect(response).to have_http_status(:ok)
    end
  end
  
  describe 'GET /posts/:id' do
    it 'shows post details' do
      get post_path(post)
      expect(response).to have_http_status(:ok)
    end
  end
  
  describe 'POST /posts' do
    context 'with valid params' do
      it 'creates a post' do
        sign_in user
        expect {
          post posts_path, params: {
            post: attributes_for(:post)
          }
        }.to change(Post, :count).by(1)
        expect(response).to redirect_to(Post.last)
      end
    end
    
    context 'with invalid params' do
      it 'does not create post' do
        sign_in user
        expect {
          post posts_path, params: {
            post: { title: '' }
          }
        }.not_to change(Post, :count)
      end
    end
  end
  
  describe 'DELETE /posts/:id' do
    it 'deletes post' do
      sign_in user
      expect {
        delete post_path(post)
      }.to change(Post, :count).by(-1)
    end
  end
end
```

## Request Spec (API)

```ruby
require 'rails_helper'

RSpec.describe 'Api::V1::Posts', type: :request do
  let(:user) { create(:user) }
  
  describe 'GET /api/v1/posts' do
    it 'returns list of posts' do
      create_list(:post, 3)
      get '/api/v1/posts'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end
  end
  
  describe 'POST /api/v1/posts' do
    it 'creates a post' do
      post '/api/v1/posts', 
        headers: { Authorization: "Bearer #{user.api_token}" },
        params: {
          post: attributes_for(:post)
        }
      expect(response).to have_http_status(:created)
    end
  end
end
```

## Job Spec

```ruby
require 'rails_helper'

RSpec.describe SendWelcomeEmailJob, type: :job do
  let(:user) { create(:user) }
  
  it 'enqueues the job' do
    expect {
      SendWelcomeEmailJob.perform_later(user.id)
    }.to have_enqueued_job(SendWelcomeEmailJob)
  end
  
  it 'sends email' do
    expect {
      SendWelcomeEmailJob.perform_now(user.id)
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
end
```

## Feature Spec (System Test)

```ruby
require 'rails_helper'

RSpec.describe 'Creating a post', type: :system do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end
  
  it 'user can create a post' do
    visit new_post_path
    fill_in 'Title', with: 'My First Post'
    fill_in 'Content', with: 'This is my first post'
    click_button 'Create Post'
    expect(page).to have_text('My First Post')
  end
end
```
