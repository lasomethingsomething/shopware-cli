#!/bin/bash

# Shopware Docker Installation Script
# Based on: https://developer.shopware.com/docs/guides/installation/setups/docker.html

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PROJECT_NAME="my-shopware-project"
DEFAULT_PHP_VERSION="8.3"
DEFAULT_NODE_VERSION="24"
DEFAULT_WEBSERVER="caddy"
DEFAULT_SHOPWARE_VERSION="latest"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to ask yes/no questions
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to ask for input with default value
ask_input() {
    local prompt="$1"
    local default="$2"
    local response
    
    read -p "$prompt [$default]: " response
    echo "${response:-$default}"
}

# Check for container runtime (Docker, OrbStack, Podman)
check_container_runtime() {
    print_info "Checking for container runtime..."
    
    local docker_installed=false
    local orbstack_installed=false
    local podman_installed=false
    local selected_runtime=""
    
    # Check for Docker
    if command -v docker &> /dev/null; then
        docker_installed=true
        print_success "Docker found: $(docker --version)"
    fi
    
    # Check for OrbStack (macOS)
    if [[ "$OSTYPE" == "darwin"* ]] && command -v orb &> /dev/null; then
        orbstack_installed=true
        print_success "OrbStack found"
    fi
    
    # Check for Podman
    if command -v podman &> /dev/null; then
        podman_installed=true
        print_success "Podman found: $(podman --version)"
    fi
    
    # If nothing is installed
    if ! $docker_installed && ! $orbstack_installed && ! $podman_installed; then
        print_error "No container runtime found!"
        echo ""
        print_info "Available options:"
        echo "  1. Docker - Standard container runtime (https://docs.docker.com/get-docker/)"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  2. OrbStack - Lightweight Docker alternative for macOS (https://orbstack.dev/)"
        fi
        
        echo "  3. Podman - Docker alternative (https://podman.io/)"
        echo ""
        
        if ask_yes_no "Would you like installation instructions?"; then
            echo ""
            echo "Installation instructions:"
            echo ""
            echo "Docker:"
            echo "  Visit: https://docs.docker.com/get-docker/"
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo ""
                echo "OrbStack (Recommended for macOS):"
                echo "  Visit: https://orbstack.dev/"
                echo "  Or install via Homebrew: brew install orbstack"
            fi
            
            echo ""
            echo "Podman:"
            echo "  Visit: https://podman.io/getting-started/installation"
        fi
        
        exit 1
    fi
    
    # If multiple runtimes are available, ask user to choose
    if (($docker_installed + $orbstack_installed + $podman_installed > 1)); then
        echo ""
        print_warning "Multiple container runtimes detected!"
        echo "Available options:"
        
        local option=1
        declare -A options
        
        if $docker_installed; then
            echo "  $option. Docker"
            options[$option]="docker"
            ((option++))
        fi
        
        if $orbstack_installed; then
            echo "  $option. OrbStack (Recommended for macOS)"
            options[$option]="orbstack"
            ((option++))
        fi
        
        if $podman_installed; then
            echo "  $option. Podman"
            options[$option]="podman"
            ((option++))
        fi
        
        echo ""
        read -p "Select runtime to use [1]: " runtime_choice
        runtime_choice=${runtime_choice:-1}
        
        selected_runtime=${options[$runtime_choice]}
        
        if [[ -z "$selected_runtime" ]]; then
            print_error "Invalid selection"
            exit 1
        fi
    else
        # Only one runtime available
        if $docker_installed; then
            selected_runtime="docker"
        elif $orbstack_installed; then
            selected_runtime="orbstack"
        elif $podman_installed; then
            selected_runtime="podman"
        fi
    fi
    
    print_success "Using: $selected_runtime"
    echo "$selected_runtime"
}

# Check for Docker Compose
check_docker_compose() {
    local runtime="$1"
    
    print_info "Checking for Docker Compose..."
    
    # Docker Compose v2 (docker compose) or v1 (docker-compose)
    if docker compose version &> /dev/null; then
        print_success "Docker Compose found: $(docker compose version)"
        return 0
    elif command -v docker-compose &> /dev/null; then
        print_success "Docker Compose found: $(docker-compose --version)"
        return 0
    else
        print_error "Docker Compose not found!"
        echo ""
        
        if ask_yes_no "Would you like installation instructions?"; then
            echo ""
            echo "Docker Compose installation:"
            echo "  Visit: https://docs.docker.com/compose/install/"
            echo ""
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "On macOS with Homebrew:"
                echo "  brew install docker-compose"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "On Linux:"
                echo "  sudo apt-get install docker-compose-plugin"
                echo "  or"
                echo "  sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
                echo "  sudo chmod +x /usr/local/bin/docker-compose"
            fi
        fi
        
        exit 1
    fi
}

# Check for make
check_make() {
    print_info "Checking for make..."
    
    if command -v make &> /dev/null; then
        print_success "make found: $(make --version | head -n1)"
        return 0
    else
        print_error "make not found!"
        echo ""
        
        if ask_yes_no "Would you like to install make?"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                print_info "Installing make via Homebrew..."
                brew install make
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                print_info "Installing make..."
                sudo apt-get update && sudo apt-get install -y make
            else
                print_error "Automatic installation not supported for your OS"
                exit 1
            fi
            
            print_success "make installed successfully"
        else
            exit 1
        fi
    fi
}

# Check Linux user ID
check_linux_user_id() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        local user_id=$(id -u)
        
        if [[ "$user_id" != "1000" ]]; then
            print_warning "Your user ID is $user_id, but the Docker setup expects user ID 1000"
            print_warning "This is a known limitation on Linux and may cause permission issues"
            
            if ! ask_yes_no "Do you want to continue anyway?"; then
                exit 1
            fi
        fi
    fi
}

# Select project configuration
configure_project() {
    echo ""
    print_info "=== Project Configuration ==="
    echo ""
    
    # Project name
    PROJECT_NAME=$(ask_input "Enter project name" "$DEFAULT_PROJECT_NAME")
    
    # PHP version
    echo ""
    print_info "Available PHP versions: 8.2, 8.3, 8.4"
    PHP_VERSION=$(ask_input "Select PHP version" "$DEFAULT_PHP_VERSION")
    
    # Node version
    echo ""
    print_info "Available Node versions: 22, 24"
    NODE_VERSION=$(ask_input "Select Node version" "$DEFAULT_NODE_VERSION")
    
    # Web server
    echo ""
    print_info "Available web servers: caddy, nginx"
    WEBSERVER=$(ask_input "Select web server" "$DEFAULT_WEBSERVER")
    
    # Shopware version
    echo ""
    print_info "Shopware version (e.g., 6.6.10.0 or 'latest')"
    SHOPWARE_VERSION=$(ask_input "Enter Shopware version" "$DEFAULT_SHOPWARE_VERSION")
    
    # Docker image
    DOCKER_IMAGE="ghcr.io/shopware/docker-dev:php${PHP_VERSION}-node${NODE_VERSION}-${WEBSERVER}"
    
    echo ""
    print_success "Configuration:"
    echo "  Project name: $PROJECT_NAME"
    echo "  PHP version: $PHP_VERSION"
    echo "  Node version: $NODE_VERSION"
    echo "  Web server: $WEBSERVER"
    echo "  Shopware version: $SHOPWARE_VERSION"
    echo "  Docker image: $DOCKER_IMAGE"
    echo ""
    
    if ! ask_yes_no "Proceed with this configuration?" "y"; then
        print_info "Configuration cancelled"
        exit 0
    fi
}

# Configure OrbStack routing
configure_orbstack() {
    local runtime="$1"
    
    if [[ "$runtime" == "orbstack" ]]; then
        echo ""
        if ask_yes_no "Would you like to use OrbStack routing (recommended for OrbStack)?"; then
            USE_ORBSTACK_ROUTING=true
            print_info "OrbStack routing will be configured"
            print_info "Your project will be accessible at: https://web.${PROJECT_NAME}.orb.local"
        else
            USE_ORBSTACK_ROUTING=false
        fi
    else
        USE_ORBSTACK_ROUTING=false
    fi
}

# Configure optional features
configure_optional_features() {
    echo ""
    print_info "=== Optional Features ==="
    echo ""
    
    # Minio S3
    if ask_yes_no "Add Minio for local S3 storage?"; then
        ADD_MINIO=true
    else
        ADD_MINIO=false
    fi
    
    # XDebug
    if ask_yes_no "Enable XDebug for PHP debugging?"; then
        ENABLE_XDEBUG=true
    else
        ENABLE_XDEBUG=false
    fi
    
    # Production image proxy
    if ask_yes_no "Set up production image proxy?"; then
        SETUP_IMAGE_PROXY=true
        PRODUCTION_URL=$(ask_input "Enter production URL (e.g., shopware.com)" "")
    else
        SETUP_IMAGE_PROXY=false
    fi
}

# Create project directory
create_project_directory() {
    echo ""
    print_info "Creating project directory: $PROJECT_NAME"
    
    if [[ -d "$PROJECT_NAME" ]]; then
        print_warning "Directory '$PROJECT_NAME' already exists"
        
        if ! ask_yes_no "Do you want to use this directory?"; then
            print_error "Installation cancelled"
            exit 1
        fi
    else
        mkdir -p "$PROJECT_NAME"
        print_success "Directory created"
    fi
    
    cd "$PROJECT_NAME"
}

# Create Shopware project
create_shopware_project() {
    echo ""
    print_info "Creating Shopware project..."
    print_info "This may take several minutes..."
    echo ""
    
    if [[ "$SHOPWARE_VERSION" == "latest" ]]; then
        docker run --rm -it -v "$PWD:/var/www/html" "$DOCKER_IMAGE" new-shopware-setup
    else
        docker run --rm -it -v "$PWD:/var/www/html" "$DOCKER_IMAGE" new-shopware-setup "$SHOPWARE_VERSION"
    fi
    
    print_success "Shopware project created"
}

# Create compose.override.yaml with all selected features
create_compose_override() {
    local needs_override=false
    
    # Check if any feature requires compose.override.yaml
    if [[ "$USE_ORBSTACK_ROUTING" == true ]] || [[ "$ADD_MINIO" == true ]] || \
       [[ "$ENABLE_XDEBUG" == true ]] || [[ "$SETUP_IMAGE_PROXY" == true ]]; then
        needs_override=true
    fi
    
    if [[ "$needs_override" == false ]]; then
        return
    fi
    
    print_info "Creating compose.override.yaml with selected features..."
    
    # Start building the override file
    cat > compose.override.yaml <<'EOF'
services:
EOF
    
    # Web service configuration
    if [[ "$USE_ORBSTACK_ROUTING" == true ]] || [[ "$ENABLE_XDEBUG" == true ]]; then
        cat >> compose.override.yaml <<'EOF'
  web:
EOF
        
        # OrbStack routing - ports override
        if [[ "$USE_ORBSTACK_ROUTING" == true ]]; then
            cat >> compose.override.yaml <<'EOF'
    ports: !override []
EOF
        fi
        
        # Environment variables
        cat >> compose.override.yaml <<'EOF'
    environment:
EOF
        
        # OrbStack routing environment
        if [[ "$USE_ORBSTACK_ROUTING" == true ]]; then
            cat >> compose.override.yaml <<EOF
      APP_URL: https://web.${PROJECT_NAME}.orb.local
      SYMFONY_TRUSTED_PROXIES: REMOTE_ADDR
EOF
        fi
        
        # XDebug environment
        if [[ "$ENABLE_XDEBUG" == true ]]; then
            cat >> compose.override.yaml <<'EOF'
      - XDEBUG_MODE=debug
      - XDEBUG_CONFIG=client_host=host.docker.internal
      - PHP_PROFILER=xdebug
EOF
        fi
    fi
    
    # Mailer service (for OrbStack)
    if [[ "$USE_ORBSTACK_ROUTING" == true ]]; then
        cat >> compose.override.yaml <<'EOF'

  mailer:
    image: axllent/mailpit
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
EOF
    fi
    
    # Minio services
    if [[ "$ADD_MINIO" == true ]]; then
        cat >> compose.override.yaml <<'EOF'

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      start_period: 20s
      start_interval: 10s
      interval: 1m
      timeout: 20s
      retries: 3
    ports:
      - 9000:9000
      - 9001:9001
    volumes:
      - minio-data:/data

  minio-setup:
    image: minio/mc
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
      set -e;
      mc alias set local http://minio:9000 minioadmin minioadmin;
      mc mb local/shopware-public local/shopware-private --ignore-existing;
      mc anonymous set download local/shopware-public;
      "
    restart: no
EOF
    fi
    
    # Image proxy service
    if [[ "$SETUP_IMAGE_PROXY" == true ]]; then
        cat >> compose.override.yaml <<EOF

  imageproxy:
    image: ghcr.io/shopwarelabs/devcontainer/image-proxy
    ports:
      - "8050:80"
    environment:
      REMOTE_SERVER_HOST: $PRODUCTION_URL
EOF
    fi
    
    # Add volumes section if Minio is enabled
    if [[ "$ADD_MINIO" == true ]]; then
        cat >> compose.override.yaml <<'EOF'

volumes:
  minio-data:
EOF
    fi
    
    print_success "compose.override.yaml created"
}

# Setup Minio configuration
setup_minio_config() {
    if [[ "$ADD_MINIO" == true ]]; then
        print_info "Creating Minio configuration..."
        
        mkdir -p config/packages
        cat > config/packages/minio.yaml <<'EOF'
# yaml-language-server: $schema=https://raw.githubusercontent.com/shopware/shopware/refs/heads/trunk/config-schema.json
shopware:
  filesystem:
    public: &s3_public
      type: "amazon-s3"
      url: "http://localhost:9000/shopware-public"
      config:
        bucket: shopware-public
        endpoint: http://minio:9000
        use_path_style_endpoint: true
        region: us-east-1
        credentials:
          key: minioadmin
          secret: minioadmin
    theme: *s3_public
    sitemap: *s3_public
    private:
      type: "amazon-s3"
      config:
        bucket: shopware-private
        endpoint: http://minio:9000
        use_path_style_endpoint: true
        region: us-east-1
        credentials:
          key: minioadmin
          secret: minioadmin
EOF
        
        print_success "Minio configuration created"
        print_info "Minio console will be available at: http://localhost:9001"
        print_info "Username: minioadmin, Password: minioadmin"
    fi
}

# Setup image proxy configuration
setup_image_proxy_config() {
    if [[ "$SETUP_IMAGE_PROXY" == true ]] && [[ -n "$PRODUCTION_URL" ]]; then
        print_info "Creating image proxy configuration..."
        
        mkdir -p config/packages
        cat > config/packages/media-proxy.yaml <<'EOF'
shopware:
  filesystem:
    public:
      url: "http://localhost:8050"
EOF
        
        print_success "Image proxy configuration created"
        print_info "Images will be proxied from: $PRODUCTION_URL"
    fi
}

# Start containers
start_containers() {
    echo ""
    print_info "Starting Docker containers..."
    
    make up
    
    print_success "Containers started"
}

# Install Shopware
install_shopware() {
    echo ""
    print_info "Would you like to install Shopware now?"
    echo "  1. Install via browser (http://localhost:8000)"
    echo "  2. Install via CLI (make setup)"
    echo "  3. Skip installation (do it later)"
    echo ""
    
    read -p "Select option [2]: " install_choice
    install_choice=${install_choice:-2}
    
    case $install_choice in
        1)
            print_info "Please open your browser and navigate to:"
            if [[ "$USE_ORBSTACK_ROUTING" == true ]]; then
                echo "  https://web.${PROJECT_NAME}.orb.local"
            else
                echo "  http://localhost:8000"
            fi
            print_info "Database host: database"
            ;;
        2)
            print_info "Installing Shopware via CLI..."
            make setup
            print_success "Shopware installed!"
            print_info "Admin credentials:"
            echo "  Username: admin"
            echo "  Password: shopware"
            ;;
        3)
            print_info "Skipping installation"
            print_info "You can install later by running: make setup"
            ;;
        *)
            print_warning "Invalid option. Skipping installation."
            ;;
    esac
}

# Print final information
print_final_info() {
    echo ""
    echo "======================================"
    print_success "Installation Complete!"
    echo "======================================"
    echo ""
    
    if [[ "$USE_ORBSTACK_ROUTING" == true ]]; then
        echo "Storefront: https://web.${PROJECT_NAME}.orb.local"
        echo "Admin: https://web.${PROJECT_NAME}.orb.local/admin"
    else
        echo "Storefront: http://localhost:8000"
        echo "Admin: http://localhost:8000/admin"
    fi
    
    echo "Mailpit: http://localhost:8025"
    
    if [[ "$ADD_MINIO" == true ]]; then
        echo "Minio Console: http://localhost:9001"
    fi
    
    if [[ "$SETUP_IMAGE_PROXY" == true ]]; then
        echo "Image Proxy: http://localhost:8050"
    fi
    
    echo ""
    echo "Admin credentials:"
    echo "  Username: admin"
    echo "  Password: shopware"
    echo ""
    echo "Useful commands:"
    echo "  make up           - Start containers"
    echo "  make stop         - Stop containers"
    echo "  make down         - Remove containers (keep data)"
    echo "  make shell        - Enter container shell"
    echo "  make build-administration  - Build admin"
    echo "  make build-storefront      - Build storefront"
    echo ""
    print_info "For more information, visit: https://developer.shopware.com/docs/guides/installation/setups/docker.html"
}

# Main installation flow
main() {
    echo ""
    echo "======================================"
    echo "  Shopware Docker Installation"
    echo "======================================"
    echo ""
    
    # Run prerequisite checks
    CONTAINER_RUNTIME=$(check_container_runtime)
    check_docker_compose "$CONTAINER_RUNTIME"
    check_make
    check_linux_user_id
    
    # Configure project
    configure_project
    configure_orbstack "$CONTAINER_RUNTIME"
    configure_optional_features
    
    # Create and setup project
    create_project_directory
    create_shopware_project
    
    # Create unified compose.override.yaml with all features
    create_compose_override
    
    # Setup configuration files
    setup_minio_config
    setup_image_proxy_config
    
    # Start and install
    start_containers
    install_shopware
    
    # Show final information
    print_final_info
}

# Run main function
main
