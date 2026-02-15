# Controller Examples

## Full CRUD REST Controller (HTML)

```ruby
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :authorize_owner!, only: [:edit, :update, :destroy]
  
  def index
    @posts = current_user.posts.page(params[:page]).per(10)
  end
  
  def show
  end
  
  def new
    @post = Post.new
  end
  
  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      redirect_to @post, notice: 'Post created successfully'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @post.update(post_params)
      redirect_to @post, notice: 'Post updated successfully'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @post.destroy
    redirect_to posts_url, notice: 'Post deleted'
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def authorize_owner!
    unless @post.user == current_user
      redirect_to posts_path, alert: 'Not authorized'
    end
  end
  
  def post_params
    params.require(:post).permit(:title, :content, :tags)
  end
end
```

## API Controller with JSON

```ruby
class Api::V1::PostsController < ApplicationController
  before_action :authenticate_api_user!
  before_action :set_post, only: [:show, :update, :destroy]
  
  # GET /api/v1/posts
  def index
    posts = Post.includes(:user).page(params[:page]).per(20)
    render json: posts, each_serializer: PostSerializer
  end
  
  # GET /api/v1/posts/:id
  def show
    render json: @post, serializer: PostDetailSerializer
  end
  
  # POST /api/v1/posts
  def create
    post = current_user.posts.build(post_params)
    if post.save
      render json: post, serializer: PostSerializer, status: :created
    else
      render json: { errors: post.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH /api/v1/posts/:id
  def update
    if @post.update(post_params)
      render json: @post, serializer: PostSerializer
    else
      render json: { errors: @post.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/posts/:id
  def destroy
    @post.destroy
    head :no_content
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def post_params
    params.require(:post).permit(:title, :content, :status)
  end
end
```

## Nested Resources Controller

```ruby
class CommentsController < ApplicationController
  before_action :set_post
  before_action :set_comment, only: [:show, :update, :destroy]
  
  def index
    @comments = @post.comments.page(params[:page])
    render json: @comments
  end
  
  def create
    @comment = @post.comments.build(comment_params)
    @comment.user = current_user
    if @comment.save
      render json: @comment, status: :created
    else
      render json: @comment.errors, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize_owner!
    @comment.destroy
    head :no_content
  end
  
  private
  
  def set_post
    @post = Post.find(params[:post_id])
  end
  
  def set_comment
    @comment = @post.comments.find(params[:id])
  end
  
  def authorize_owner!
    unless @comment.user == current_user
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
  
  def comment_params
    params.require(:comment).permit(:content)
  end
end
```

## Controller with Custom Actions

```ruby
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :publish, :archive]
  
  # Publish a post (custom action)
  def publish
    @post.publish!
    render json: @post, notice: 'Post published'
  end
  
  # Archive a post (custom action)
  def archive
    @post.archive!
    render json: @post
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
end

# config/routes.rb
resources :posts do
  member do
    post :publish
    post :archive
  end
end
```
