#!/bin/bash

# Shopware Installation Script - Master Installer
# Allows users to choose between Docker, Devenv, or Symfony CLI installation methods

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Base URL for downloading scripts
BASE_URL="https://raw.githubusercontent.com/lasomethingsomething/shopware-cli/main/scripts"

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

print_header() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

# Function to download a script if it doesn't exist
download_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        print_info "Downloading $script_name..."
        if curl -fsSL "$BASE_URL/$script_name" -o "$script_path"; then
            chmod +x "$script_path"
            print_success "Downloaded $script_name"
            return 0
        else
            print_error "Failed to download $script_name"
            return 1
        fi
    fi
    return 0
}

# Display welcome banner
show_banner() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║          Shopware 6 Installation Script                   ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

# Display installation method descriptions
show_installation_methods() {
    echo ""
    print_header "Choose Your Installation Method:"
    echo ""
    
    echo -e "  ${BOLD}1. Docker${NC} (Recommended for most users)"
    echo "     • Full containerized setup with PHP, Node, and all services"
    echo "     • Works on macOS, Linux, and Windows (WSL2)"
    echo "     • Supports Docker Desktop, OrbStack, and Podman"
    echo "     • Easiest to set up and mirrors production environment"
    echo ""
    
    echo -e "  ${BOLD}2. Devenv${NC} (Advanced - Reproducible environments)"
    echo "     • Nix-based development environment"
    echo "     • Native performance (no containers/VMs)"
    echo "     • Per-project isolated binaries and services"
    echo "     • Ideal for Shopware core contributors"
    echo "     • Requires Nix package manager"
    echo ""
    
    echo -e "  ${BOLD}3. Symfony CLI${NC} (Lightweight - Use local PHP)"
    echo "     • Uses your system's PHP, Composer, and Node.js"
    echo "     • Lightweight and fast"
    echo "     • Optional Docker for database only"
    echo "     • Good if you already have PHP/MySQL installed"
    echo ""
    
    echo -e "  ${BOLD}0. Exit${NC}"
    echo ""
}

# Get user's choice
get_installation_choice() {
    local choice
    
    while true; do
        read -p "Select installation method [1]: " choice
        choice=${choice:-1}
        
        case $choice in
            1|2|3|0)
                echo "$choice"
                return 0
                ;;
            *)
                print_error "Invalid selection. Please choose 1, 2, 3, or 0."
                ;;
        esac
    done
}

# Run Docker installation
run_docker_install() {
    print_header "Starting Docker Installation..."
    echo ""
    
    local docker_script="install-docker.sh"
    local fallback_script="install-symfony-cli.sh"
    
    # Download Docker script if not present
    if ! download_script "$docker_script"; then
        print_error "Cannot proceed without $docker_script"
        print_info "Please check your internet connection and try again."
        exit 1
    fi
    
    # Pre-download the Symfony CLI fallback script silently
    # (install-docker.sh may need it if Docker isn't available)
    download_script "$fallback_script" > /dev/null 2>&1 || true
    
    # Run the script
    if [[ -f "$SCRIPT_DIR/$docker_script" ]]; then
        bash "$SCRIPT_DIR/$docker_script"
    else
        print_error "$docker_script not found after download!"
        exit 1
    fi
}

# Run Devenv installation
run_devenv_install() {
    print_header "Starting Devenv Installation..."
    echo ""
    
    local devenv_script="install-devenv.sh"
    
    # Try to download the script
    if download_script "$devenv_script"; then
        # Run the script if it exists
        if [[ -f "$SCRIPT_DIR/$devenv_script" ]]; then
            bash "$SCRIPT_DIR/$devenv_script"
        else
            print_error "$devenv_script not found after download!"
            exit 1
        fi
    else
        print_warning "$devenv_script is not yet available."
        print_info "Visit: https://developer.shopware.com/docs/guides/installation/setups/devenv.html"
        exit 1
    fi
}

# Run Symfony CLI installation
run_symfony_cli_install() {
    print_header "Starting Symfony CLI Installation..."
    echo ""
    
    local symfony_script="install-symfony-cli.sh"
    
    # Try to download the script
    if download_script "$symfony_script"; then
        # Run the script if it exists
        if [[ -f "$SCRIPT_DIR/$symfony_script" ]]; then
            bash "$SCRIPT_DIR/$symfony_script"
        else
            print_error "$symfony_script not found after download!"
            exit 1
        fi
    else
        print_warning "$symfony_script is not yet available."
        print_info "Visit: https://developer.shopware.com/docs/guides/installation/setups/symfony-cli.html"
        exit 1
    fi
}

# Show comparison to help user decide
show_comparison() {
    echo ""
    if ask_yes_no "Would you like to see a detailed comparison?"; then
        echo ""
        print_header "Installation Method Comparison:"
        echo ""
        printf "%-20s %-15s %-15s %-15s\n" "Feature" "Docker" "Devenv" "Symfony CLI"
        printf "%-20s %-15s %-15s %-15s\n" "────────────────────" "──────────────" "──────────────" "──────────────"
        printf "%-20s %-15s %-15s %-15s\n" "Setup Difficulty" "Easy" "Medium" "Easy"
        printf "%-20s %-15s %-15s %-15s\n" "Prerequisites" "Docker only" "Nix" "PHP, MySQL"
        printf "%-20s %-15s %-15s %-15s\n" "Performance" "Good" "Excellent" "Excellent"
        printf "%-20s %-15s %-15s %-15s\n" "Isolation" "Full" "Per-project" "Minimal"
        printf "%-20s %-15s %-15s %-15s\n" "Prod Similarity" "High" "Medium" "Medium"
        printf "%-20s %-15s %-15s %-15s\n" "Best For" "Most users" "Contributors" "Local dev"
        echo ""
    fi
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

# Main function
main() {
    show_banner
    show_installation_methods
    show_comparison
    
    echo ""
    choice=$(get_installation_choice)
    
    echo ""
    
    case $choice in
        1)
            run_docker_install
            ;;
        2)
            run_devenv_install
            ;;
        3)
            run_symfony_cli_install
            ;;
        0)
            print_info "Installation cancelled."
            exit 0
            ;;
    esac
}

# Run main function
main
