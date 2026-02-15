# Model Associations

Associations define relationships between models at the object level, while foreign keys define them at the database level. Active Record provides macros to declare relationships clearly and provides convenient methods for traversing these associations.

## belongs_to

A `belongs_to` association establishes a one-to-one relationship where the declaring model has a foreign key that references another model.

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user
end

# Queries the users table via the user_id foreign key
post = Post.find(1)
post.user  # => returns the associated User object

# Set the association
post.user = User.find(2)
post.save
```

**Key Points:**
- The foreign key (`user_id`) is stored on the declaring model's table (posts)
- Must provide a foreign key column in the database
- Adds methods: `user`, `user=`, `build_user`, `create_user`
- Optional by default; use `optional: false` to require the association

```ruby
class Post < ApplicationRecord
  # Require that every post has a user
  belongs_to :user, optional: false
end
```

## has_one

A `has_one` association indicates that another model has a foreign key that references this model. There is a one-to-one relationship where one record owns exactly one record.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_one :profile
end

# The foreign key (user_id) is in the profiles table
user = User.find(1)
user.profile  # => returns the associated Profile object
user.build_profile(bio: "Developer")
user.create_profile(bio: "Developer")
```

**Key Points:**
- The foreign key is stored on the associated model's table (profiles)
- Adds methods: `profile`, `profile=`, `build_profile`, `create_profile`
- Useful for splitting wide tables or managing optional associated records
- Can combine with `dependent: :destroy` to delete associated record

```ruby
class User < ApplicationRecord
  has_one :profile, dependent: :destroy
end
```

## has_many

A `has_many` association indicates a one-to-many relationship where one model owns multiple instances of another model.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :posts
end

# The foreign key (user_id) is in the posts table
user = User.find(1)
user.posts  # => returns all posts where user_id = 1
user.posts.count
user.posts.where(published: true)
user.posts.create(title: "New Post")
```

**Key Points:**
- Foreign key is on the associated model's table
- Returns a collection (array-like) of associated records
- Adds methods: `posts`, `posts=`, `posts.build`, `posts.create`, `posts.delete`, `posts.clear`
- Can specify `dependent` to handle deletion: `:destroy` (calls callbacks), `:delete_all` (direct SQL), `:nullify` (sets FK to NULL)

```ruby
class User < ApplicationRecord
  has_many :posts, dependent: :destroy  # Delete posts when user is deleted
end
```

## has_many through

A `has_many :through` association is often used to set up a many-to-many relationship through an intermediate join model.

```ruby
# Models
class User < ApplicationRecord
  has_many :enrollments
  has_many :courses, through: :enrollments
end

class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :course
end

class Course < ApplicationRecord
  has_many :enrollments
  has_many :users, through: :enrollments
end

# Usage
user = User.find(1)
user.courses  # => all courses the user is enrolled in
user.courses.create(title: "Advanced Ruby")
user.enrollments  # => all enrollment records
```

**Key Points:**
- Requires a join model (Enrollment) with foreign keys to both sides
- Provides convenient access to the far side of the relationship
- Can add extra data to the join model (e.g., enrollment date, grade)
- The through association must come before the many association in declaration

## Polymorphic Associations

Polymorphic associations allow a model to belong to more than one type of model using a single association.

```ruby
# Models
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
end

class Photo < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
end

# Database schema (comments table)
create_table :comments do |t|
  t.text :content
  t.references :commentable, polymorphic: true
  t.timestamps
end

# Usage
post = Post.find(1)
post.comments.create(content: "Great post!")

photo = Photo.find(1)
photo.comments.create(content: "Beautiful photo!")

comment = Comment.first
comment.commentable  # => either a Post or Photo object
```

**Key Points:**
- Uses two columns: `commentable_id` and `commentable_type`
- The type column stores the class name of the associated model
- Useful for comments, likes, notifications that apply to multiple model types
- Query across types with caution; usually filter by type first

```ruby
# Find comments on posts only
Post.find(1).comments
# NOT recommended: Comment.all (mixes posts and photos)
# Better: Comment.where(commentable_type: 'Post')
```

## has_many Associations with Conditions

Add conditions or scopes to associations to automatically filter records.

```ruby
class User < ApplicationRecord
  # Only published posts
  has_many :published_posts, -> { where(published: true) }, class_name: 'Post'
  
  # Recent posts (last 10)
  has_many :recent_posts, -> { order('created_at DESC').limit(10) }, class_name: 'Post'
  
  # Posts by count
  has_many :posts
end

# Usage
user.published_posts  # only published ones
user.recent_posts     # last 10 in reverse order
```

## Self-Referential Associations

A model can have associations with itself.

```ruby
class User < ApplicationRecord
  has_many :followers, class_name: 'User', foreign_key: 'following_id'
  belongs_to :following, class_name: 'User', optional: true
end

# Database schema
create_table :users do |t|
  t.string :name
  t.references :following, foreign_key: { to_table: :users }
  t.timestamps
end

# Usage
user1 = User.find(1)
user2 = User.find(2)

user2.following = user1
user2.save

user1.followers  # => returns user2
```

## Association Methods

Each association provides several convenient methods:

### For belongs_to and has_one

```ruby
post.user              # Get the associated object
post.user=             # Set the associated object
post.build_user        # Create new unsaved User instance
post.create_user       # Create and save new User instance
post.reload_user       # Refresh from database
post.user_changed?     # Check if association was changed
```

### For has_many

```ruby
user.posts             # Get all associated posts
user.posts=            # Replace all posts
user.posts.build       # Create new unsaved Post instance
user.posts.create      # Create and save new Post instance
user.posts.find        # Find specific post(s)
user.posts.where       # Find with conditions
user.posts.count       # Count associated records
user.posts.delete_all  # Delete all associated records
user.posts.clear       # Remove association (set FK to NULL)
```

## Best Practices

- **Name associations in singular/plural consistently**: `has_many :posts`, `belongs_to :user`
- **Avoid N+1 queries**: Use `includes` or `joins` when accessing associations in loops
- **Use `dependent` carefully**: Choose between `:destroy`, `:delete_all`, `:nullify` based on your needs
- **Test associations**: Verify with factories that create associated records properly
- **Document polymorphic types**: Make it clear which models can be polymorphic associations
- **Avoid circular dependencies**: Be careful with bidirectional associations that could cause infinite loops
