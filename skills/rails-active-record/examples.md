# Examples

Practical, real-world implementations demonstrating Active Record patterns in common scenarios.

## User with Posts and Comments

A simple blog structure with users, posts, and comments.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  
  validates :email, :username, presence: true
  validates :email, :username, uniqueness: true
  validates :username, length: { minimum: 3, maximum: 20 }
end

# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  
  validates :title, :content, :user_id, presence: true
  validates :title, length: { minimum: 5, maximum: 200 }
  
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  
  def publish!
    update(published: true, published_at: Time.current)
  end
end

# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user
  
  validates :content, :post_id, :user_id, presence: true
  validates :content, length: { minimum: 1, maximum: 5000 }
  
  scope :recent, -> { order(created_at: :desc) }
end

# Database schema
create_table :users do |t|
  t.string :username, null: false
  t.string :email, null: false
  t.timestamps
end
add_index :users, [:email, :username], unique: true

create_table :posts do |t|
  t.references :user, null: false, foreign_key: true
  t.string :title, null: false
  t.text :content, null: false
  t.boolean :published, default: false
  t.datetime :published_at
  t.timestamps
end
add_index :posts, [:user_id, :published]

create_table :comments do |t|
  t.references :post, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.text :content, null: false
  t.timestamps
end
add_index :comments, [:post_id, :user_id]

# Usage
user = User.create(username: 'john_doe', email: 'john@example.com')
post = user.posts.create(title: 'Hello Rails', content: 'Active Record is awesome')
post.publish!

comment = post.comments.create(user: user, content: 'Great post!')

# Queries
Post.published.recent.includes(:user, :comments)
user.posts.count
user.comments.recent
```

## Polymorphic Comments and Likes

Allow comments and likes on multiple resources (posts, videos, photos).

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user
  
  validates :content, :commentable_type, :commentable_id, :user_id, presence: true
  
  scope :on_posts, -> { where(commentable_type: 'Post') }
  scope :on_videos, -> { where(commentable_type: 'Video') }
end

# app/models/like.rb
class Like < ApplicationRecord
  belongs_to :likeable, polymorphic: true
  belongs_to :user
  
  validates :likeable_type, :likeable_id, :user_id, presence: true
  validates :user_id, uniqueness: { scope: [:likeable_type, :likeable_id] }
  
  scope :on_posts, -> { where(likeable_type: 'Post') }
  scope :on_videos, -> { where(likeable_type: 'Video') }
end

# app/models/post.rb
class Post < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
end

# app/models/video.rb
class Video < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
end

# app/models/photo.rb
class Photo < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
end

# Database schema
create_table :comments do |t|
  t.text :content
  t.references :commentable, polymorphic: true
  t.references :user, foreign_key: true
  t.timestamps
end

create_table :likes do |t|
  t.references :likeable, polymorphic: true
  t.references :user, foreign_key: true
  t.timestamps
end

# Usage
post = Post.find(1)
video = Video.find(1)

# Add comments
post.comments.create(user: user, content: 'Great post!')
video.comments.create(user: user, content: 'Nice video!')

# Add likes
post.likes.create(user: user)
video.likes.create(user: user)

# Query polymorphic
Comment.on_posts  # Comments only on posts
Like.on_videos  # Likes only on videos
post.comments.count
post.likes.count
```

## Through Associations: Courses and Enrollments

Students enrolled in multiple courses with enrollment metadata.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :enrollments
  has_many :courses, through: :enrollments
  
  scope :by_course, ->(course) { joins(:enrollments).where(enrollments: { course_id: course.id }) }
end

# app/models/enrollment.rb
class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :course
  
  validates :user_id, :course_id, presence: true
  validates :user_id, uniqueness: { scope: :course_id }
  
  enum status: { pending: 0, active: 1, completed: 2 }
  
  scope :active, -> { where(status: :active) }
end

# app/models/course.rb
class Course < ApplicationRecord
  has_many :enrollments
  has_many :users, through: :enrollments
  has_many :students, through: :enrollments, source: :user
  
  validates :title, :code, presence: true
  validates :code, uniqueness: true
end

# Database schema
create_table :enrollments do |t|
  t.references :user, null: false, foreign_key: true
  t.references :course, null: false, foreign_key: true
  t.integer :status, default: 0
  t.datetime :enrolled_at
  t.datetime :completed_at
  t.timestamps
end
add_index :enrollments, [:user_id, :course_id], unique: true

# Usage
user = User.find(1)
course = Course.find(1)

enrollment = Enrollment.create(user: user, course: course, status: :active)

user.courses  # All courses user is enrolled in
course.users  # All users in course
course.students  # Same as users

# Query by enrollment status
user.enrollments.active
Enrollment.where(user: user, status: :active).map(&:course)
```

## Tags with Many-to-Many Relationships

Posts can have many tags, and tags can appear on many posts.

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  has_many :taggings
  has_many :tags, through: :taggings
  
  scope :tagged_with, ->(tag_names) {
    joins(:tags).where(tags: { name: tag_names })
  }
end

# app/models/tag.rb
class Tag < ApplicationRecord
  has_many :taggings
  has_many :posts, through: :taggings
  
  validates :name, presence: true, uniqueness: true
  
  scope :popular, -> { joins(:taggings).group('tags.id').order('count(*) DESC') }
end

# app/models/tagging.rb
class Tagging < ApplicationRecord
  belongs_to :post
  belongs_to :tag
end

# Database schema
create_table :tags do |t|
  t.string :name, null: false
  t.timestamps
end
add_index :tags, :name, unique: true

create_table :taggings do |t|
  t.references :post, null: false, foreign_key: true
  t.references :tag, null: false, foreign_key: true
  t.timestamps
end

# Usage
post = Post.find(1)
ruby_tag = Tag.find_or_create_by(name: 'ruby')
rails_tag = Tag.find_or_create_by(name: 'rails')

post.tags << [ruby_tag, rails_tag]
post.tags  # => [ruby_tag, rails_tag]

Post.tagged_with(['ruby'])
Tag.popular  # Most used tags
```

## Soft Deletes with Paranoia

Posts that can be "deleted" but preserved in database.

```ruby
# Gemfile
gem 'paranoia'

# app/models/post.rb
class Post < ApplicationRecord
  acts_as_paranoid
  
  belongs_to :user
  has_many :comments, dependent: :destroy
end

# Database migration
create_table :posts do |t|
  t.references :user, foreign_key: true
  t.string :title
  t.text :content
  t.datetime :deleted_at  # Added by paranoia
  t.timestamps
end
add_index :posts, :deleted_at

# Usage
post = Post.find(1)
post.destroy  # Sets deleted_at, doesn't remove from DB

Post.all  # Doesn't include soft-deleted posts
Post.with_deleted  # Includes soft-deleted
Post.only_deleted  # Only deleted posts
post.restore  # Un-soft-delete
```

## Single Table Inheritance: Payment Methods

Different payment types (Credit Card, PayPal, Bank Transfer) in one table.

```ruby
# app/models/payment_method.rb
class PaymentMethod < ApplicationRecord
  belongs_to :user
  
  validates :user_id, presence: true
  validates :name, presence: true
  
  scope :active, -> { where(active: true) }
end

# app/models/credit_card.rb
class CreditCard < PaymentMethod
  validates :card_number, :expiry_month, :expiry_year, :cvv, presence: true
  validates :card_number, length: { is: 16 }
  
  def masked_number
    card_number.last(4).rjust(16, '*')
  end
end

# app/models/paypal_account.rb
class PaypalAccount < PaymentMethod
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# app/models/bank_transfer.rb
class BankTransfer < PaymentMethod
  validates :account_number, :routing_number, presence: true
end

# Database schema
create_table :payment_methods do |t|
  t.string :type  # STI discriminator
  t.references :user, null: false, foreign_key: true
  t.string :name
  
  # Credit card fields
  t.string :card_number
  t.integer :expiry_month
  t.integer :expiry_year
  t.string :cvv
  
  # PayPal fields
  t.string :email
  
  # Bank transfer fields
  t.string :account_number
  t.string :routing_number
  
  t.boolean :active, default: true
  t.timestamps
end

# Usage
user = User.find(1)

cc = CreditCard.create!(
  user: user,
  name: 'My Visa',
  card_number: '4532015112830366',
  expiry_month: 12,
  expiry_year: 2025,
  cvv: '123'
)

paypal = PaypalAccount.create!(
  user: user,
  name: 'My PayPal',
  email: 'user@example.com'
)

user.payment_methods  # All payment methods
CreditCard.all  # Only credit cards
cc.masked_number  # => "****5366"
```

## Order with Items and Calculations

Orders with line items and automatic total calculations.

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  
  validates :user_id, presence: true
  
  enum status: { pending: 0, paid: 1, shipped: 2, delivered: 3 }
  
  before_save :calculate_totals
  
  scope :recent, -> { order(created_at: :desc) }
  
  def calculate_totals
    self.subtotal = order_items.sum { |item| item.quantity * item.price }
    self.tax = subtotal * 0.08
    self.total = subtotal + tax
  end
end

# app/models/order_item.rb
class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  
  validates :order_id, :product_id, :quantity, :price, presence: true
  validates :quantity, :price, numericality: { greater_than: 0 }
  
  def line_total
    quantity * price
  end
end

# app/models/product.rb
class Product < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :orders, through: :order_items
end

# Database schema
create_table :orders do |t|
  t.references :user, null: false, foreign_key: true
  t.decimal :subtotal, precision: 10, scale: 2
  t.decimal :tax, precision: 10, scale: 2
  t.decimal :total, precision: 10, scale: 2
  t.integer :status, default: 0
  t.timestamps
end

create_table :order_items do |t|
  t.references :order, null: false, foreign_key: true
  t.references :product, null: false, foreign_key: true
  t.integer :quantity, null: false
  t.decimal :price, precision: 10, scale: 2, null: false
  t.timestamps
end

# Usage
user = User.find(1)
product = Product.find(1)

order = user.orders.create!
order.order_items.create!(product: product, quantity: 2, price: 19.99)
order.save!

order.subtotal  # => 39.98
order.total  # => 43.1784
```

## Querying Complex Relationships

Advanced queries combining multiple conditions.

```ruby
# Find posts with comments from admin users
Post.joins(comments: :user)
  .where(users: { role: 'admin' })
  .distinct

# Find users with published posts created in the last month
User.joins(:posts)
  .where(posts: { published: true })
  .where("posts.created_at > ?", 1.month.ago)
  .distinct

# Find courses with active enrollments, sorted by student count
Course.joins(:enrollments)
  .where(enrollments: { status: :active })
  .group('courses.id')
  .select('courses.*, COUNT(enrollments.id) as student_count')
  .order('student_count DESC')

# Find tags that appear on multiple posts
Tag.joins(:posts)
  .group('tags.id')
  .having('COUNT(posts.id) > 1')
  .order('COUNT(posts.id) DESC')
```

These examples demonstrate core Active Record patterns in realistic scenarios. Adjust for your specific use cases and always test thoroughly.
