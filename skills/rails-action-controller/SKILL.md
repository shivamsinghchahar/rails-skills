---
name: rails-action-controller
description: Build Rails Action Controllers to handle HTTP requests with RESTful actions, routing, strong parameters, callbacks, and filters. Use when creating API endpoints, handling authentication/authorization, managing request lifecycles, working with cookies/sessions, or building both JSON and HTML responses.
---

# Rails Action Controllers

Master HTTP request handling with Action Controller, building RESTful endpoints, managing request/response cycles, implementing authentication, and handling callbacks.

## When to Use This Skill

- Building REST API endpoints or web controllers
- Handling HTTP requests, parameters, and responses
- Implementing authentication and authorization filters
- Managing cookies, sessions, and flash messages
- Working with routing, URL parameters, and path helpers
- Handling errors and exceptions in controller actions
- Building both JSON API and HTML template responses
- Implementing before/after/around action callbacks

## Quick Start

Build RESTful controllers with proper action structure, parameter handling, and request lifecycle management.

## Quick Start

Generate a controller:
```bash
rails generate controller Posts index show create update destroy
```

Create a controller:
```ruby
class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: [:show, :update, :destroy]
  
  def index
    @posts = Post.all
    render json: @posts
  end
  
  def show
    render json: @post
  end
  
  def create
    @post = Post.new(post_params)
    if @post.save
      render json: @post, status: :created
    else
      render json: @post.errors, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def post_params
    params.require(:post).permit(:title, :content)
  end
end
```

## Core Topics

**Routing & Parameters**: See [routing-params.md](routing-params.md) for RESTful routing, nested resources, and params handling.

**Filters & Callbacks**: See [filters-callbacks.md](filters-callbacks.md) for before/after actions, authentication, authorization, and exception handling.

**Patterns**: See [patterns.md](patterns.md) for request lifecycle, strong parameters, error handling, and JSON/HTML responses.

**Sessions & Cookies**: See [references/sessions-cookies.md](references/sessions-cookies.md) for session management, flash messages, and cookie handling (signed, encrypted, permanent).

**Advanced Authentication**: See [references/authentication-advanced.md](references/authentication-advanced.md) for HTTP authentication, token-based auth, JWT, OAuth 2.0, and error handling with `rescue_from`.

**Streaming & Downloads**: See [references/streaming-downloads.md](references/streaming-downloads.md) for file downloads, uploads, streaming responses, and Server-Sent Events.

## Scripts

**REST Controller Scaffold**: [scripts/rest-controller-scaffold.sh](scripts/rest-controller-scaffold.sh) generates a complete REST controller with CRUD actions.

**API Controller Template**: [scripts/api-controller-template.sh](scripts/api-controller-template.sh) generates an API-only controller with authentication and error handling.

## Examples

See [examples.md](examples.md) for:
- Full CRUD controller implementation
- Nested resource controllers
- API vs HTML rendering
- Error handling and status codes
