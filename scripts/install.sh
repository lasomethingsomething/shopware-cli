#!/usr/bin/env bash
# Shopware Installation Script - Master Installer
# Dispatches to install-docker.sh, install-devenv.sh or install-symfony-cli.sh
# Improved: safer flags, trap, non-interactive mode, dependency checks

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
BLUE='\033[0;34m' CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults (can be overridden via env var or CLI)
INSTALL_METHOD="${INSTALL_METHOD:-}"   # "docker", "devenv", "symfony"
AUTO_YES="${AUTO_YES:-false}"          # if true skip prompts

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
print_header() { echo -e "${CYAN}${BOLD}$*${NC}"; }

# Trap to show failing command + line for easier debugging
trap 'ret=$?; echo -e "${RED}[ERROR] Command failed at line $LINENO (exit $ret)${NC}"; exit $ret' ERR

# Print banner (removed 'clear' to avoid clearing terminal scrollback)
show_banner() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║                                                            ║"
  echo "║              Shopware 6 Installation Script                ║"
  echo "║                                                            ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

show_installation_methods() {
  print_header "Choose Your Installation Method:"
  echo ""
  echo "  1) Docker        (Recommended - full containerized setup)"
  echo "  2) Devenv        (Nix-based reproducible environment)"
  echo "  3) Symfony CLI   (Lightweight - uses local PHP/Composer)"
  echo ""
  echo "  0) Exit"
  echo ""
}

# helper to parse CLI args (very small arg parser)
parse_args() {
  while [[ "${#}" -gt 0 ]]; do
    case "$1" in
      --method|-m)
        INSTALL_METHOD="${2:-}"; shift 2 ;;
      --yes|-y)
        AUTO_YES=true; shift ;;
      --help|-h)
        cat <<EOF
Usage: $0 [--method docker|devenv|symfony] [--yes]
Environment variable: INSTALL_METHOD, AUTO_YES
EOF
        exit 0 ;;
      *)
        echo "Unknown arg: $1"; exit 1 ;;
    esac
  done
}

# Ask yes/no helper (respects AUTO_YES)
ask_yes_no() {
  local prompt="${1:-Continue?}" default="${2:-n}"

  if [[ "$AUTO_YES" == "true" ]]; then
    return 0
  fi

  local resp
  if [[ "${default}" == "y" ]]; then
    read -r -p "${prompt} [Y/n]: " resp
    resp="${resp:-Y}"
  else
    read -r -p "${prompt} [y/N]: " resp
    resp="${resp:-N}"
  fi

  case "$resp" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Validate that the child scripts exist
check_child_script() {
  local f="$1"
  if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
    log_error "$f not found in $SCRIPT_DIR"
    exit 1
  fi
  if [[ ! -x "$SCRIPT_DIR/$f" ]]; then
    log_warn "$f is not executable; will run with bash"
  fi
}

# Dispatcher functions
run_docker_install() {
  print_header "Starting Docker Installation..."
  check_child_script "install-docker.sh"
  bash "$SCRIPT_DIR/install-docker.sh"
}

run_devenv_install() {
  print_header "Starting Devenv Installation..."
  check_child_script "install-devenv.sh"
  bash "$SCRIPT_DIR/install-devenv.sh"
}

run_symfony_cli_install() {
  print_header "Starting Symfony CLI Installation..."
  check_child_script "install-symfony-cli.sh"
  bash "$SCRIPT_DIR/install-symfony-cli.sh"
}

# interactive menu (only used if INSTALL_METHOD not set)
get_installation_choice() {
  local choice
  while true; do
    read -r -p "Select installation method [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      1|2|3|0) echo "$choice"; return 0 ;;
      *) log_error "Invalid selection. Please choose 1, 2, 3, or 0." ;;
    esac
  done
}

# show comparison table (kept from original, but simplified)
show_comparison() {
  if ask_yes_no "Would you like to see a brief comparison?" "n"; then
    print_header "Installation Method Comparison:"
    printf "%-20s %-12s %-12s %-12s\n" "Feature" "Docker" "Devenv" "Symfony"
    printf "%-20s %-12s %-12s %-12s\n" "Setup Difficulty" "Easy" "Medium" "Easy"
    printf "%-20s %-12s %-12s %-12s\n" "Prerequisites" "Docker" "Nix" "PHP/MySQL"
    printf "%-20s %-12s %-12s %-12s\n" "Best For" "Most users" "Contributors" "Local dev"
    echo ""
  fi
}

main() {
  parse_args "$@"
  show_banner
  show_installation_methods
  show_comparison

  # Non-interactive via INSTALL_METHOD
  if [[ -n "${INSTALL_METHOD}" ]]; then
    case "${INSTALL_METHOD}" in
      docker) run_docker_install; exit ;;
      devenv) run_devenv_install; exit ;;
      symfony) run_symfony_cli_install; exit ;;
      *) log_error "Unknown INSTALL_METHOD: ${INSTALL_METHOD}"; exit 1 ;;
    esac
  fi

  local choice
  choice=$(get_installation_choice)
  case $choice in
    1) run_docker_install ;;
    2) run_devenv_install ;;
    3) run_symfony_cli_install ;;
    0) log_info "Installation cancelled."; exit 0 ;;
  esac
}

main "$@"
