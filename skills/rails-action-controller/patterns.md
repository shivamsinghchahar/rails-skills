# Controller Patterns

## Standard REST Actions

```ruby
class PostsController < ApplicationController
  # GET /posts
  def index
    @posts = Post.all
  end
  
  # GET /posts/:id
  def show
    @post = Post.find(params[:id])
  end
  
  # GET /posts/new
  def new
    @post = Post.new
  end
  
  # POST /posts
  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post, notice: 'Post created'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  # GET /posts/:id/edit
  def edit
    @post = Post.find(params[:id])
  end
  
  # PATCH/PUT /posts/:id
  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to @post, notice: 'Post updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /posts/:id
  def destroy
    @post = Post.find(params[:id])
    @post.destroy
    redirect_to posts_url, notice: 'Post deleted'
  end
  
  private
  
  def post_params
    params.require(:post).permit(:title, :content)
  end
end
```

## API vs HTML Rendering

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])
    
    respond_to do |format|
      format.html { render :show }
      format.json { render json: @post }
    end
  end
  
  def create
    @post = Post.new(post_params)
    if @post.save
      render json: @post, status: :created
    else
      render json: @post.errors, status: :unprocessable_entity
    end
  end
end
```

## JSON with Serializers

```ruby
# Use ActiveModelSerializers or similar
class PostsController < ApplicationController
  def index
    posts = Post.all
    render json: posts, each_serializer: PostSerializer
  end
  
  def show
    post = Post.find(params[:id])
    render json: post, serializer: PostSerializer, include: 'user,comments'
  end
end
```

## Nested Resources

```ruby
class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @posts = @user.posts
  end
end

class PostsController < ApplicationController
  before_action :set_user
  
  def index
    @posts = @user.posts
  end
  
  private
  
  def set_user
    @user = User.find(params[:user_id])
  end
end

# config/routes.rb
resources :users do
  resources :posts
end
```

## Pagination

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.page(params[:page]).per(20)
    render json: @posts
  end
end

# Requires gem 'kaminari' or 'will_paginate'
```

## Filtering and Sorting

```ruby
class PostsController < ApplicationController
  def index
    posts = Post.all
    posts = posts.where(status: params[:status]) if params[:status]
    posts = posts.order(params[:sort] || 'created_at DESC')
    render json: posts
  end
end

# GET /posts?status=published&sort=title
```
