# Filters and Callbacks

## before_action / after_action

Execute code before/after actions:

```ruby
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :update, :destroy]
  before_action :authorize_user!, only: [:update, :destroy]
  after_action :log_activity, except: [:index]
  
  def show
    # set_post already called
    render json: @post
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def authorize_user!
    unless @post.user == current_user
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
  
  def log_activity
    Activity.create!(user: current_user, action: action_name)
  end
end
```

## Action Filtering Options

```ruby
# Run only for certain actions
before_action :admin_check, only: [:edit, :update]
before_action :authenticate, except: [:index, :show]

# With if condition
before_action :maybe_authenticate, if: :needs_auth?

# Conditional logic
before_action do
  @current_ability = current_user.ability if current_user
end

private

def needs_auth?
  !%(index show).include?(action_name)
end
```

## Exception Handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  private
  
  def record_not_found
    render json: { error: 'Not found' }, status: :not_found
  end
  
  def user_not_authorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end

class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])  # Raises if not found
  end
end
```

## Halting Actions

```ruby
class PostsController < ApplicationController
  before_action :check_permission, only: [:edit]
  
  def edit
    # Never reached if check_permission returns false
  end
  
  private
  
  def check_permission
    unless current_user.admin?
      head :forbidden  # Stop execution, return 403
    end
  end
end
```

## Around Filters

Execute before and after:

```ruby
class PostsController < ApplicationController
  around_action :measure_performance
  
  private
  
  def measure_performance
    start_time = Time.current
    yield
    elapsed = Time.current - start_time
    Rails.logger.info "Action took #{elapsed}s"
  end
end
```
