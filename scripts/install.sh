#!/bin/bash

# Shopware Installation Script - Master Installer
# Allows users to choose between Docker, Devenv, or Symfony CLI installation methods
# Extended to auto-detect Docker, Podman, Colima, OrbStack

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

# ---- PRINT HELPERS ---------------------------------------------------------

print_info()       { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success()    { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()      { echo -e "${RED}[ERROR]${NC} $1"; }
print_header()     { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ---- BANNER ---------------------------------------------------------------

show_banner() {
    # DO NOT CLEAR SCROLLBACK — replace "clear" with safe screen clear
    printf "\033[2J\033[H"
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║               Shopware 6 Installation Script               ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

# ---- METHOD DESCRIPTIONS --------------------------------------------------

show_installation_methods() {
    echo ""
    print_header "Choose Your Installation Method:"
    echo ""
    
    echo "  ${BOLD}1. Docker${NC} (Recommended for most users)"
    echo "     • Supports Docker Desktop, OrbStack, Podman, Colima"
    echo "     • Full containerized setup"
    echo ""

    echo "  ${BOLD}2. Devenv${NC} (Advanced - Nix-based)"
    echo ""

    echo "  ${BOLD}3. Symfony CLI${NC} (Local PHP)"
    echo ""

    echo "  ${BOLD}0. Exit${NC}"
    echo ""
}

# ---- YES/NO PROMPTS --------------------------------------------------------

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

    [[ "$response" =~ ^[Yy]$ ]]
}

# ---- CHOICE ---------------------------------------------------------------

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

# ---- RUNTIME DETECTION LOGIC ----------------------------------------------

docker_ok()   { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
podman_ok()   { command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; }
colima_ok()   { command -v colima >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
orbstack_ok() { command -v orbstack >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

start_docker_desktop() {
    if [[ "$(uname -s)" == "Darwin" && -d "/Applications/Docker.app" ]]; then
        print_info "Starting Docker Desktop..."
        open -a Docker || true
        for _ in {1..20}; do
            docker_ok && return 0
            sleep 1
        done
    fi
    return 1
}

start_orbstack() {
    if command -v orbstack >/dev/null 2>&1; then
        print_info "Starting OrbStack..."
        orbstack start || true
        for _ in {1..20}; do
            orbstack_ok && return 0
            sleep 1
        done
    fi
    return 1
}

start_podman() {
    if command -v podman >/dev/null 2>&1; then
        print_info "Starting Podman machine..."
        podman machine start || true
        for _ in {1..20}; do
            podman_ok && return 0
            sleep 1
        done
    fi
    return 1
}

start_colima() {
    if command -v colima >/dev/null 2>&1; then
        print_info "Starting Colima..."
        colima start || true
        for _ in {1..20}; do
            colima_ok && return 0
            sleep 1
        done
    fi
    return 1
}

# ---- DOCKER INSTALL --------------------------------------------------------

run_docker_install() {
    print_header "Starting Docker Installation..."
    echo ""

    # STEP 1: AUTO-DETECT active runtime
    RUNTIME=""
    docker_ok   && RUNTIME="docker"
    [[ -z "$RUNTIME" && orbstack_ok ]] && RUNTIME="orbstack"
    [[ -z "$RUNTIME" && podman_ok   ]] && RUNTIME="podman"
    [[ -z "$RUNTIME" && colima_ok   ]] && RUNTIME="colima"

    # STEP 2: TRY STARTING runtimes (priority order)
    if [[ -z "$RUNTIME" ]]; then
        start_docker_desktop && RUNTIME="docker"
    fi
    if [[ -z "$RUNTIME" ]]; then
        start_orbstack && RUNTIME="orbstack"
    fi
    if [[ -z "$RUNTIME" ]]; then
        start_podman && RUNTIME="podman"
    fi
    if [[ -z "$RUNTIME" ]]; then
        start_colima && RUNTIME="colima"
    fi

    # STILL no runtime?
    if [[ -z "$RUNTIME" ]]; then
        print_error "No container runtime is available."
        print_warning "Start Docker Desktop, OrbStack, Podman, or Colima and re-run."
        exit 1
    fi

    print_success "Using runtime: $RUNTIME"
    export SHOPWARE_RUNTIME="$RUNTIME"

    # DELEGATE to install-docker.sh
    if [[ -f "$SCRIPT_DIR/install-docker.sh" ]]; then
        RUNTIME="$RUNTIME" bash "$SCRIPT_DIR/install-docker.sh"
    else
        print_error "install-docker.sh not found!"
        exit 1
    fi
}

# ---- DEVENv INSTALL --------------------------------------------------------

run_devenv_install() {
    print_header "Starting Devenv Installation..."
    echo ""
    if [[ -f "$SCRIPT_DIR/install-devenv.sh" ]]; then
        bash "$SCRIPT_DIR/install-devenv.sh"
    else
        print_error "install-devenv.sh not found!"
        exit 1
    fi
}

# ---- SYMFONY CLI INSTALL ---------------------------------------------------

run_symfony_cli_install() {
    print_header "Starting Symfony CLI Installation..."
    echo ""
    if [[ -f "$SCRIPT_DIR/install-symfony-cli.sh" ]]; then
        bash "$SCRIPT_DIR/install-symfony-cli.sh"
    else
        print_error "install-symfony-cli.sh not found!"
        exit 1
    fi
}

# ---- MAIN -----------------------------------------------------------------

main() {
    show_banner
    show_installation_methods
    echo ""
    choice=$(get_installation_choice)
    echo ""

    case $choice in
        1) run_docker_install ;;
        2) run_devenv_install ;;
        3) run_symfony_cli_install ;;
        0) print_info "Installation cancelled."; exit 0 ;;
    esac
}

main
