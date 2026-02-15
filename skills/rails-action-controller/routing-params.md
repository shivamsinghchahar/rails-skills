# Routing and Parameters

## RESTful Routes

```ruby
# config/routes.rb
resources :posts                          # 7 standard actions
resources :posts, only: [:index, :show]  # Limited actions
resources :posts, except: [:destroy]     # Exclude actions

# Nested resources
resources :users do
  resources :posts
end

# Shallow nesting (avoids deep paths)
resources :users do
  resources :posts, shallow: true
end
```

## Strong Parameters

Always whitelist parameters:

```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)
  end
  
  private
  
  def post_params
    params.require(:post).permit(:title, :content, :status)
  end
end
```

### Permitting Arrays and Hashes

```ruby
def article_params
  params.require(:article).permit(
    :title,
    :content,
    tags: [],                    # Array of strings
    metadata: [:author, :date],  # Array of hashes
    author_attributes: [:name, :email]  # Nested attributes
  )
end
```

## Accessing Parameters

```ruby
class PostsController < ApplicationController
  def create
    # params is a hash-like object
    params[:post]              # Access by key
    params[:id]                # URL parameters
    params.permit(:title)      # Whitelist params
    params.to_unsafe_h         # Convert to hash (avoid)
    params.fetch(:status, 'draft')  # With default
  end
end
```

## Named Routes

Routes generate helper methods:

```ruby
resources :posts

# Generates helpers:
post_path(@post)           # /posts/1
posts_path                 # /posts
edit_post_path(@post)      # /posts/1/edit
new_post_path              # /posts/new
post_url(@post)            # Full URL: http://example.com/posts/1
```

## Custom Routes

```ruby
resources :posts do
  member do
    post :publish
    patch :archive
  end
  
  collection do
    get :trending
    post :bulk_delete
  end
end

# Generates:
# POST /posts/1/publish     (member: single resource)
# GET /posts/trending       (collection: all resources)
```
