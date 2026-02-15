#!/bin/bash
# Generate a REST controller scaffold with CRUD actions
# Usage: bash rest-controller-scaffold.sh PostsController Post

if [ $# -lt 2 ]; then
    echo "Usage: $0 ControllerName ModelName"
    echo "Example: $0 PostsController Post"
    exit 1
fi

CONTROLLER_NAME=$1
MODEL_NAME=$2

# Convert to snake_case for file name
CONTROLLER_FILE=$(echo "$CONTROLLER_NAME" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')

# Generate using Rails generator
rails generate controller "$CONTROLLER_NAME" index show new create edit update destroy --skip-template-engine

# Create the controller implementation
cat > "app/controllers/${CONTROLLER_FILE}.rb" << 'EOF'
class '"$CONTROLLER_NAME"' < ApplicationController
  before_action :set_'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"', only: [:show, :edit, :update, :destroy]

  # GET /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]' | sed 's/$/s/')"'
  def index
    @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]' | sed 's/$/s/')"' = '"$MODEL_NAME"'.all
    render json: @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]' | sed 's/$/s/')"'
  end

  # GET /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'/:id
  def show
    render json: @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'
  end

  # GET /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'/new
  def new
    @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"' = '"$MODEL_NAME"'.new
  end

  # POST /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]' | sed 's/$/s/')"'
  def create
    @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"' = '"$MODEL_NAME"'.new('"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'_params)

    if @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'.save
      render json: @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"', status: :created
    else
      render json: @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'.errors, status: :unprocessable_entity
    end
  end

  # GET /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'/:id/edit
  def edit
  end

  # PATCH/PUT /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'/:id
  def update
    if @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'.update('"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'_params)
      render json: @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"', status: :ok
    else
      render json: @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'.errors, status: :unprocessable_entity
    end
  end

  # DELETE /'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'/:id
  def destroy
    @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'.destroy
    render json: { message: "Deleted successfully" }, status: :ok
  end

  private

  def set_'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'
    @'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"' = '"$MODEL_NAME"'.find(params[:id])
  end

  def '"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"'_params
    params.require(:'"$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]')"').permit(:attribute1, :attribute2)
  end
end
EOF

echo "✅ REST Controller scaffold created for $CONTROLLER_NAME"
echo "   File: app/controllers/${CONTROLLER_FILE}.rb"
echo ""
echo "📝 Next steps:"
echo "   1. Update the permitted parameters in ${CONTROLLER_FILE}_params"
echo "   2. Add model validations and associations"
echo "   3. Add routes to config/routes.rb: resources :$(echo $MODEL_NAME | tr '[:upper:]' '[:lower:]' | sed 's/$/s/')"
echo "   4. Run tests with: rails test"
