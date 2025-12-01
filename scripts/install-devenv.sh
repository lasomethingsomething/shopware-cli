#!/bin/bash

# Shopware Devenv Installation Script
# Based on: https://developer.shopware.com/docs/guides/installation/setups/devenv.html

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PROJECT_NAME="my-shopware-project"

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

# Check if Nix is installed
check_nix() {
    print_info "Checking for Nix..."
    
    if command -v nix &> /dev/null; then
        print_success "Nix found: $(nix --version)"
        return 0
    else
        print_error "Nix not found!"
        echo ""
        print_warning "Nix is required for Devenv."
        echo ""
        
        if ask_yes_no "Would you like to install Nix now?" "y"; then
            install_nix
        else
            print_info "Installation instructions:"
            echo "  Visit: https://nixos.org/download.html"
            echo "  Or run: curl -L https://install.determinate.systems/nix | sh -s -- install"
            exit 1
        fi
    fi
}

# Install Nix
install_nix() {
    print_info "Installing Nix using Determinate Systems installer..."
    echo ""
    
    print_warning "This will download and run the Nix installer."
    if ! ask_yes_no "Continue?"; then
        exit 1
    fi
    
    curl -L https://install.determinate.systems/nix | sh -s -- install
    
    print_success "Nix installed!"
    print_warning "Please restart your terminal and run this script again."
    exit 0
}

# Check if Devenv is installed
check_devenv() {
    print_info "Checking for Devenv..."
    
    if command -v devenv &> /dev/null; then
        print_success "Devenv found: $(devenv --version)"
        return 0
    else
        print_error "Devenv not found!"
        echo ""
        
        if ask_yes_no "Would you like to install Devenv now?" "y"; then
            install_devenv
        else
            print_info "To install Devenv manually, run:"
            echo "  nix profile install github:cachix/devenv/latest"
            exit 1
        fi
    fi
}

# Install Devenv
install_devenv() {
    print_info "Installing Devenv..."
    
    nix profile install github:cachix/devenv/latest
    
    print_success "Devenv installed!"
    
    # Verify installation
    if command -v devenv &> /dev/null; then
        print_success "Devenv is now available: $(devenv --version)"
    else
        print_warning "Devenv installed but not found in PATH."
        print_info "Try restarting your terminal or sourcing your shell config."
    fi
}

# Check for Git
check_git() {
    print_info "Checking for Git..."
    
    if command -v git &> /dev/null; then
        print_success "Git found: $(git --version)"
        return 0
    else
        print_error "Git is required but not found!"
        print_info "Please install Git and try again."
        exit 1
    fi
}

# Check for common port conflicts
check_port_conflicts() {
    print_info "Checking for port conflicts..."
    
    local ports_in_use=()
    
    # Check common ports: 8000 (Caddy), 3306 (MySQL), 6379 (Redis), 9080 (Adminer), 8025 (Mailhog)
    for port in 8000 3306 6379 9080 8025; do
        if lsof -i :$port &> /dev/null || ss -tuln 2>/dev/null | grep -q ":$port "; then
            ports_in_use+=($port)
        fi
    done
    
    if [ ${#ports_in_use[@]} -gt 0 ]; then
        print_warning "The following ports are already in use: ${ports_in_use[*]}"
        print_warning "Devenv services may fail to start if these ports are occupied."
        echo ""
        
        if ! ask_yes_no "Do you want to continue anyway?"; then
            print_info "Please free up the ports and try again."
            exit 1
        fi
    else
        print_success "No port conflicts detected"
    fi
}

# Configure project
configure_project() {
    echo ""
    print_info "=== Project Configuration ==="
    echo ""
    
    PROJECT_NAME=$(ask_input "Enter project name" "$DEFAULT_PROJECT_NAME")
    
    echo ""
    print_info "Shopware version (e.g., 6.6.10.0 or 'latest' for trunk)"
    SHOPWARE_VERSION=$(ask_input "Enter Shopware version" "latest")
}

# Check if using Shopware core or production template
configure_project_type() {
    echo ""
    print_info "What type of project would you like to create?"
    echo "  1. Production template (standard projects)"
    echo "  2. Shopware core (for contributors)"
    echo ""
    
    read -p "Select project type [1]: " project_type
    project_type=${project_type:-1}
    
    case $project_type in
        1)
            PROJECT_TYPE="production"
            ;;
        2)
            PROJECT_TYPE="core"
            ;;
        *)
            print_warning "Invalid selection, using production template"
            PROJECT_TYPE="production"
            ;;
    esac
}

# Configure optional features
configure_optional_features() {
    echo ""
    print_info "=== Optional Features ==="
    echo ""
    
    # Direnv
    if ask_yes_no "Install and configure Direnv for automatic environment activation?" "y"; then
        INSTALL_DIRENV=true
    else
        INSTALL_DIRENV=false
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

# Clone or create project
setup_project() {
    echo ""
    
    if [[ "$PROJECT_TYPE" == "core" ]]; then
        print_info "Cloning Shopware core repository..."
        git clone https://github.com/shopware/shopware.git .
        print_success "Shopware core cloned"
    else
        print_info "Creating Shopware production project..."
        print_info "This may take several minutes..."
        echo ""
        
        # Use Nix to run Composer
        nix-shell -p php83 composer --run "composer create-project shopware/production ."
        
        print_success "Shopware project created"
        
        # Create devenv.nix for production template
        create_devenv_config
    fi
}

# Create devenv.nix configuration
create_devenv_config() {
    print_info "Creating devenv.nix configuration..."
    
    cat > devenv.nix <<'EOF'
{ pkgs, lib, config, ... }:

{
  packages = with pkgs; [
    git
  ];

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_20;
  };

  languages.php = {
    enable = true;
    version = "8.3";
    extensions = [ "apcu" "bcmath" "ctype" "curl" "dom" "fileinfo" "gd" "iconv" "intl" "json" "mbstring" "opcache" "openssl" "pcntl" "pdo" "pdo_mysql" "session" "simplexml" "sodium" "tokenizer" "xml" "xmlreader" "xmlwriter" "zip" "zlib" ];
    ini = ''
      memory_limit = 512M
      realpath_cache_ttl = 3600
      session.gc_probability = 0
      display_errors = On
      error_reporting = E_ALL
      assert.active = 0
      opcache.memory_consumption = 256M
      opcache.interned_strings_buffer = 20
      zend.assertions = 0
      short_open_tag = 0
      zend.detect_unicode = 0
      realpath_cache_ttl = 3600
    '';
    fpm.pools.web = {
      settings = {
        "clear_env" = "no";
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 10;
      };
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."http://localhost:8000" = {
      extraConfig = ''
        root * public
        php_fastcgi unix/${config.languages.php.fpm.pools.web.socket}
        file_server
      '';
    };
  };

  services.mysql = {
    enable = true;
    package = pkgs.mysql80;
    initialDatabases = [{ name = "shopware"; }];
    ensureUsers = [
      {
        name = "shopware";
        password = "shopware";
        ensurePermissions = { "shopware.*" = "ALL PRIVILEGES"; };
      }
    ];
  };

  services.redis = {
    enable = true;
  };

  services.mailhog.enable = true;

  services.adminer = {
    enable = true;
    listen = "127.0.0.1:9080";
  };

  env.COMPOSER_HOME = "${config.env.DEVENV_STATE}/composer";
}
EOF
    
    print_success "devenv.nix created"
}

# Install Direnv
install_direnv() {
    if [[ "$INSTALL_DIRENV" != true ]]; then
        return
    fi
    
    print_info "Setting up Direnv..."
    
    if ! command -v direnv &> /dev/null; then
        print_info "Installing Direnv..."
        nix profile install nixpkgs#direnv
    else
        print_success "Direnv already installed"
    fi
    
    # Create .envrc
    echo "use devenv" > .envrc
    
    print_info "Allowing Direnv for this directory..."
    direnv allow
    
    print_success "Direnv configured"
    print_info "Direnv will automatically activate when you enter this directory"
    
    # Show hook installation instructions
    echo ""
    print_warning "To enable Direnv globally, add this to your shell config:"
    echo ""
    
    if [[ "$SHELL" == *"zsh"* ]]; then
        echo "  # Add to ~/.zshrc:"
        echo "  eval \"\$(direnv hook zsh)\""
    elif [[ "$SHELL" == *"bash"* ]]; then
        echo "  # Add to ~/.bashrc:"
        echo "  eval \"\$(direnv hook bash)\""
    else
        echo "  Visit: https://direnv.net/docs/hook.html"
    fi
}

# Start Devenv
start_devenv() {
    echo ""
    print_info "Starting Devenv services..."
    print_warning "This will run in the foreground. Press Ctrl+C to stop."
    echo ""
    
    if ask_yes_no "Start Devenv now?"; then
        devenv up
    else
        print_info "Skipping startup. You can start Devenv later with: devenv up"
    fi
}

# Install Shopware
install_shopware() {
    echo ""
    print_info "Installing Shopware..."
    
    if ask_yes_no "Install Shopware now?" "y"; then
        print_info "Entering Devenv shell and installing Shopware..."
        
        devenv shell -- bin/console system:install --basic-setup --create-database --force
        
        print_success "Shopware installed!"
    else
        print_info "Skipping installation. You can install later with:"
        echo "  devenv shell"
        echo "  bin/console system:install --basic-setup --create-database --force"
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
    echo "Adminer: http://localhost:9080"
    echo "Mailhog: http://localhost:8025"
    echo ""
    
    echo "Database connection:"
    echo "  Host: 127.0.0.1:3306"
    echo "  User: shopware"
    echo "  Password: shopware"
    echo "  Database: shopware"
    echo ""
    
    echo "Admin credentials:"
    echo "  Username: admin"
    echo "  Password: shopware"
    echo ""
    
    echo "Useful commands:"
    echo "  devenv up          - Start all services"
    echo "  devenv shell       - Enter development shell"
    echo "  devenv info        - Show environment info"
    
    if [[ "$INSTALL_DIRENV" == true ]]; then
        echo ""
        print_info "Direnv is configured. When you cd into this directory, the environment will activate automatically."
    fi
    
    echo ""
    print_info "For more information, visit: https://developer.shopware.com/docs/guides/installation/setups/devenv.html"
}

# Main installation flow
main() {
    echo ""
    echo "======================================"
    echo "  Shopware Devenv Installation"
    echo "======================================"
    echo ""
    
    # Run prerequisite checks
    check_nix
    check_devenv
    check_git
    check_port_conflicts
    
    # Configure project
    configure_project
    configure_project_type
    configure_optional_features
    
    # Create and setup project
    create_project_directory
    setup_project
    
    # Optional features
    install_direnv
    
    # Show next steps
    print_final_info
    
    # Optionally start services
    echo ""
    start_devenv
}

# Run main function
main
