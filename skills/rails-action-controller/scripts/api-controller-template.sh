#!/bin/bash
# Generate an API-only controller template
# Usage: bash api-controller-template.sh PostsController

if [ $# -lt 1 ]; then
    echo "Usage: $0 ControllerName"
    echo "Example: $0 PostsController"
    exit 1
fi

CONTROLLER_NAME=$1

# Convert to snake_case for file name
CONTROLLER_FILE=$(echo "$CONTROLLER_NAME" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')

# Create the API controller template
mkdir -p "app/controllers/api"

cat > "app/controllers/api/${CONTROLLER_FILE}.rb" << 'EOF'
module Api
  class '"$CONTROLLER_NAME"' < ApplicationController
    before_action :authenticate_request!
    before_action :set_resource, only: [:show, :update, :destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

    # GET /api/resources
    def index
      @resources = Resource.all
      render json: @resources, status: :ok
    end

    # GET /api/resources/:id
    def show
      render json: @resource, status: :ok
    end

    # POST /api/resources
    def create
      @resource = Resource.new(resource_params)

      if @resource.save
        render json: @resource, status: :created, location: @resource
      else
        render json: @resource.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /api/resources/:id
    def update
      if @resource.update(resource_params)
        render json: @resource, status: :ok
      else
        render json: @resource.errors, status: :unprocessable_entity
      end
    end

    # DELETE /api/resources/:id
    def destroy
      @resource.destroy
      render json: { message: "Resource deleted successfully" }, status: :ok
    end

    private

    def set_resource
      @resource = Resource.find(params[:id])
    end

    def resource_params
      params.require(:resource).permit(:attribute1, :attribute2)
    end

    def authenticate_request!
      token = request.headers["Authorization"]&.sub(/^Bearer\s+/, "")
      render json: { error: "Unauthorized" }, status: :unauthorized unless token
      @current_user = User.find_by(api_token: token)
      render json: { error: "Invalid token" }, status: :unauthorized unless @current_user
    end

    def not_found
      render json: { error: "Resource not found" }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: { 
        error: "Validation failed",
        details: exception.record.errors
      }, status: :unprocessable_entity
    end
  end
end
EOF

echo "✅ API Controller template created"
echo "   File: app/controllers/api/${CONTROLLER_FILE}.rb"
echo ""
echo "📝 Integration steps:"
echo "   1. Update Resource model name in the controller"
echo "   2. Update resource_params to match your model"
echo "   3. Implement user authentication in authenticate_request!"
echo "   4. Add to config/routes.rb:"
echo "      namespace :api do"
echo "        resources :$(echo $CONTROLLER_FILE | sed 's/_//g' | sed 's/controller//')"
echo "      end"
echo "   5. Test with curl:"
echo "      curl -H 'Authorization: Bearer YOUR_TOKEN' http://localhost:3000/api/resources"
