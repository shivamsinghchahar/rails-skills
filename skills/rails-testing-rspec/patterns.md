# Testing Patterns

## DRY Specs with Shared Examples

```ruby
shared_examples 'a validatable model' do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_least(2) }
end

RSpec.describe User do
  it_behaves_like 'a validatable model'
end

RSpec.describe Post do
  it_behaves_like 'a validatable model'
end
```

## Test Organization

```ruby
RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:posts) }
  end
  
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
  end
  
  describe '.active' do
    it 'returns only active users' do
      active = create(:user)
      inactive = create(:user, :inactive)
      expect(User.active).to eq([active])
    end
  end
  
  describe '#full_name' do
    it 'concatenates first and last name' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end
end
```

## Reduce Database Calls

```ruby
# Good: Minimal database use
RSpec.describe User do
  describe 'validations' do
    subject { build(:user) }  # Not saved
    it { is_expected.to validate_presence_of(:email) }
  end
end

# Bad: Creates user in database
RSpec.describe User do
  before { @user = create(:user) }  # Saved to database
end
```

## Matcher Chain

```ruby
# shoulda-matchers gem
it { is_expected.to have_many(:posts) }
it { is_expected.to have_one(:profile) }
it { is_expected.to belong_to(:user) }
it { is_expected.to validate_presence_of(:email) }
it { is_expected.to validate_uniqueness_of(:email) }
it { is_expected.to allow_value('test@example.com').for(:email) }
```

## Setup Data Efficiently

```ruby
RSpec.describe Post do
  let(:user) { create(:user) }      # Lazy evaluation
  let(:post) { create(:post, user: user) }
  
  it 'belongs to a user' do
    expect(post.user).to eq(user)
  end
  
  # Use let! to immediately evaluate
  let!(:other_posts) { create_list(:post, 3) }
end
```

## Testing Callbacks

```ruby
RSpec.describe User do
  describe 'callbacks' do
    describe 'before_create' do
      it 'generates api token' do
        user = build(:user)
        expect(user.api_token).to be_nil
        user.save
        expect(user.api_token).not_to be_nil
      end
    end
  end
end
```

## Testing Scopes

```ruby
RSpec.describe Post do
  describe '.published' do
    let!(:published) { create(:post, published: true) }
    let!(:draft) { create(:post, published: false) }
    
    it 'returns only published posts' do
      expect(Post.published).to contain_exactly(published)
    end
  end
end
```
