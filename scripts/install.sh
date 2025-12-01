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

# Display welcome banner
show_banner() {
    clear
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
    
    echo "  ${BOLD}1. Docker${NC} (Recommended for most users)"
    echo "     • Full containerized setup with PHP, Node, and all services"
    echo "     • Works on macOS, Linux, and Windows (WSL2)"
    echo "     • Supports Docker Desktop, OrbStack, and Podman"
    echo "     • Easiest to set up and mirrors production environment"
    echo ""
    
    echo "  ${BOLD}2. Devenv${NC} (Advanced - Reproducible environments)"
    echo "     • Nix-based development environment"
    echo "     • Native performance (no containers/VMs)"
    echo "     • Per-project isolated binaries and services"
    echo "     • Ideal for Shopware core contributors"
    echo "     • Requires Nix package manager"
    echo ""
    
    echo "  ${BOLD}3. Symfony CLI${NC} (Lightweight - Use local PHP)"
    echo "     • Uses your system's PHP, Composer, and Node.js"
    echo "     • Lightweight and fast"
    echo "     • Optional Docker for database only"
    echo "     • Good if you already have PHP/MySQL installed"
    echo ""
    
    echo "  ${BOLD}0. Exit${NC}"
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
    
    if [[ -f "$SCRIPT_DIR/install-docker.sh" ]]; then
        bash "$SCRIPT_DIR/install-docker.sh"
    else
        print_error "install-docker.sh not found!"
        print_info "Please ensure the script is in the same directory as this installer."
        exit 1
    fi
}

# Run Devenv installation
run_devenv_install() {
    print_header "Starting Devenv Installation..."
    echo ""
    
    if [[ -f "$SCRIPT_DIR/install-devenv.sh" ]]; then
        bash "$SCRIPT_DIR/install-devenv.sh"
    else
        print_error "install-devenv.sh not found!"
        print_info "This installation method is not yet available."
        print_info "Visit: https://developer.shopware.com/docs/guides/installation/setups/devenv.html"
        exit 1
    fi
}

# Run Symfony CLI installation
run_symfony_cli_install() {
    print_header "Starting Symfony CLI Installation..."
    echo ""
    
    if [[ -f "$SCRIPT_DIR/install-symfony-cli.sh" ]]; then
        bash "$SCRIPT_DIR/install-symfony-cli.sh"
    else
        print_error "install-symfony-cli.sh not found!"
        print_info "This installation method is not yet available."
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
