#!/bin/bash

# Shopware Symfony CLI Installation Script
# Based on: https://developer.shopware.com/docs/guides/installation/setups/symfony-cli.html

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

# Check for Symfony CLI
check_symfony_cli() {
    print_info "Checking for Symfony CLI..."
    
    if command -v symfony &> /dev/null; then
        print_success "Symfony CLI found: $(symfony version)"
        return 0
    else
        print_error "Symfony CLI not found!"
        echo ""
        
        if ask_yes_no "Would you like installation instructions?"; then
            echo ""
            echo "Symfony CLI installation:"
            echo "  Visit: https://symfony.com/download"
            echo ""
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "On macOS:"
                echo "  brew install symfony-cli/tap/symfony-cli"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "On Linux:"
                echo "  wget https://get.symfony.com/cli/installer -O - | bash"
            fi
            echo ""
        fi
        
        exit 1
    fi
}

# Check for PHP
check_php() {
    print_info "Checking for PHP..."
    
    if command -v php &> /dev/null; then
        local php_version=$(php -r 'echo PHP_VERSION;')
        print_success "PHP found: $php_version"
        
        # Check if PHP version is at least 8.2
        if php -r 'exit(version_compare(PHP_VERSION, "8.2.0") >= 0 ? 0 : 1);'; then
            print_success "PHP version is compatible (8.2+)"
        else
            print_warning "PHP 8.2 or higher is required. Current version: $php_version"
            
            if ! ask_yes_no "Do you want to continue anyway?"; then
                exit 1
            fi
        fi
        
        # Check for intl extension
        if php -m | grep -q intl; then
            print_success "PHP intl extension found"
        else
            print_warning "PHP intl extension not found (required)"
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "  Install with: brew install php-intl"
            fi
        fi
    else
        print_error "PHP not found!"
        print_info "Please install PHP 8.2+ and try again."
        exit 1
    fi
}

# Check for Composer
check_composer() {
    print_info "Checking for Composer..."
    
    if command -v composer &> /dev/null; then
        print_success "Composer found: $(composer --version | head -n1)"
        
        # Check if Composer 2.x
        if composer --version | grep -q "Composer version 2"; then
            print_success "Composer 2.x detected"
        else
            print_warning "Composer 2.x is recommended"
        fi
    else
        print_error "Composer not found!"
        echo ""
        
        if ask_yes_no "Would you like installation instructions?"; then
            echo ""
            echo "Composer installation:"
            echo "  Visit: https://getcomposer.org/download/"
        fi
        
        exit 1
    fi
}

# Check for Node.js
check_nodejs() {
    print_info "Checking for Node.js..."
    
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        print_success "Node.js found: $node_version"
        
        # Check if Node version is at least 20
        local major_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $major_version -ge 20 ]]; then
            print_success "Node.js version is compatible (20+)"
        else
            print_warning "Node.js 20+ is recommended. Current version: $node_version"
        fi
    else
        print_error "Node.js not found!"
        print_info "Please install Node.js 20+ and try again."
        print_info "Visit: https://nodejs.org/"
        exit 1
    fi
    
    if command -v npm &> /dev/null; then
        print_success "npm found: $(npm --version)"
    else
        print_warning "npm not found"
    fi
}

# Check for MySQL/MariaDB
check_database() {
    print_info "Checking for MySQL/MariaDB..."
    
    local mysql_found=false
    local mariadb_found=false
    
    if command -v mysql &> /dev/null; then
        mysql_found=true
        print_success "MySQL client found"
    fi
    
    if command -v mariadb &> /dev/null; then
        mariadb_found=true
        print_success "MariaDB client found"
    fi
    
    if ! $mysql_found && ! $mariadb_found; then
        print_warning "MySQL/MariaDB client not found on host"
        echo ""
        print_info "You can either:"
        echo "  1. Install MySQL 8+ or MariaDB 11+ locally"
        echo "  2. Use Docker for the database"
    fi
}

# Check for Docker (optional)
check_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker found: $(docker --version)"
        DOCKER_AVAILABLE=true
    else
        DOCKER_AVAILABLE=false
    fi
}

# Configure project
configure_project() {
    echo ""
    print_info "=== Project Configuration ==="
    echo ""
    
    PROJECT_NAME=$(ask_input "Enter project name" "$DEFAULT_PROJECT_NAME")
    
    echo ""
    print_info "Shopware version (e.g., 6.6.10.0 or leave empty for latest)"
    SHOPWARE_VERSION=$(ask_input "Enter Shopware version" "")
}

# Configure database
configure_database() {
    echo ""
    print_info "=== Database Configuration ==="
    echo ""
    
    if [[ "$DOCKER_AVAILABLE" == true ]]; then
        if ask_yes_no "Use Docker for database?"; then
            USE_DOCKER_DB=true
            DB_HOST="127.0.0.1"
            DB_PORT="3306"
            DB_USER="shopware"
            DB_PASS="shopware"
            DB_NAME="shopware"
        else
            USE_DOCKER_DB=false
            configure_manual_database
        fi
    else
        print_info "Docker not available. Using manual database configuration."
        USE_DOCKER_DB=false
        configure_manual_database
    fi
}

# Configure manual database connection
configure_manual_database() {
    DB_HOST=$(ask_input "Database host" "127.0.0.1")
    DB_PORT=$(ask_input "Database port" "3306")
    DB_USER=$(ask_input "Database user" "root")
    DB_PASS=$(ask_input "Database password" "")
    DB_NAME=$(ask_input "Database name" "shopware")
}

# Configure PHP version
configure_php_version() {
    echo ""
    if ask_yes_no "Set specific PHP version for this project?"; then
        PHP_VERSION=$(ask_input "PHP version (e.g., 8.3)" "$DEFAULT_PHP_VERSION")
        SET_PHP_VERSION=true
    else
        SET_PHP_VERSION=false
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
    
    if [[ -n "$SHOPWARE_VERSION" ]]; then
        symfony composer create-project shopware/production:$SHOPWARE_VERSION .
    else
        symfony composer create-project shopware/production .
    fi
    
    print_success "Shopware project created"
}

# Configure environment
configure_environment() {
    print_info "Configuring environment..."
    
    # Create .env.local
    cat > .env.local <<EOF
# Database Configuration
DATABASE_URL=mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}

# Application URL
APP_URL=http://localhost:8000
EOF
    
    print_success ".env.local created"
    
    # Set PHP version if requested
    if [[ "$SET_PHP_VERSION" == true ]]; then
        echo "$PHP_VERSION" > .php-version
        print_success ".php-version created"
    fi
}

# Start Docker database
start_docker_database() {
    if [[ "$USE_DOCKER_DB" != true ]]; then
        return
    fi
    
    echo ""
    print_info "Starting Docker database..."
    
    docker compose up -d
    
    print_success "Database container started"
    
    # Wait for database to be ready
    print_info "Waiting for database to be ready..."
    sleep 5
}

# Install Shopware
install_shopware() {
    echo ""
    print_info "Installing Shopware..."
    
    if ask_yes_no "Install Shopware now?" "y"; then
        symfony console system:install --basic-setup --create-database
        
        print_success "Shopware installed!"
        print_info "Admin credentials:"
        echo "  Username: admin"
        echo "  Password: shopware"
    else
        print_info "Skipping installation. You can install later with:"
        echo "  symfony console system:install --basic-setup --create-database"
    fi
}

# Start web server
start_webserver() {
    echo ""
    print_info "Starting Symfony web server..."
    
    if ask_yes_no "Start web server now?"; then
        if ask_yes_no "Start in background?" "y"; then
            symfony server:start -d
            print_success "Web server started in background"
        else
            print_info "Starting web server in foreground..."
            print_warning "Press Ctrl+C to stop"
            symfony server:start
        fi
    else
        print_info "Skipping web server start. You can start it later with:"
        echo "  symfony server:start"
    fi
}

# Print final information
print_final_info() {
    echo ""
    echo "======================================"
    print_success "Installation Complete!"
    echo "======================================"
    echo ""
    
    echo "Storefront: http://localhost:8000"
    echo "Admin: http://localhost:8000/admin"
    echo ""
    
    echo "Admin credentials:"
    echo "  Username: admin"
    echo "  Password: shopware"
    echo ""
    
    echo "Database:"
    echo "  Host: $DB_HOST:$DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo ""
    
    echo "Useful commands:"
    echo "  symfony server:start      - Start web server"
    echo "  symfony server:stop       - Stop web server"
    echo "  symfony console [command] - Run Symfony console commands"
    
    if [[ "$USE_DOCKER_DB" == true ]]; then
        echo "  docker compose up -d      - Start database"
        echo "  docker compose down       - Stop database"
    fi
    
    echo ""
    print_info "For more information, visit: https://developer.shopware.com/docs/guides/installation/setups/symfony-cli.html"
}

# Main installation flow
main() {
    echo ""
    echo "======================================"
    echo "  Shopware Symfony CLI Installation"
    echo "======================================"
    echo ""
    
    # Run prerequisite checks
    check_symfony_cli
    check_php
    check_composer
    check_nodejs
    check_database
    check_docker
    
    # Configure project
    configure_project
    configure_database
    configure_php_version
    
    # Create and setup project
    create_project_directory
    create_shopware_project
    configure_environment
    
    # Start services
    start_docker_database
    install_shopware
    
    # Show final information
    print_final_info
    
    # Start web server
    start_webserver
}

# Run main function
main
