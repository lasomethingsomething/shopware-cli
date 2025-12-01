#!/usr/bin/env bash
# Shopware Installation Script - Master Installer
set -euo pipefail
IFS=$'\n\t'

# Colors for output — correct ANSI escape sequences
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
CYAN=$'\e[0;36m'
BOLD=$'\e[1m'
NC=$'\e[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
print_header(){ echo -e "${CYAN}${BOLD}$*${NC}"; }

trap 'ret=$?; echo -e "${RED}[ERROR] Command failed at line $LINENO (exit $ret)${NC}"; exit $ret' ERR

# Print banner (no scrollback clearing)
show_banner() {
  printf "\033[2J\033[H"
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
  echo -e "  ${BOLD}1) Docker${NC}        (Recommended - full containerized setup)"
  echo -e "  ${BOLD}2) Devenv${NC}        (Nix-based reproducible environment)"
  echo -e "  ${BOLD}3) Symfony CLI${NC}   (Lightweight - uses local PHP/Composer)"
  echo ""
  echo -e "  ${BOLD}0) Exit${NC}"
  echo ""
}

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

ask_yes_no() {
  local prompt="${1:-Continue?}" default="${2:-n}"
  if [[ "$AUTO_YES" == "true" ]]; then return 0; fi
  local resp
  if [[ "$default" == "y" ]]; then
    read -r -p "${prompt} [Y/n]: " resp
    resp="${resp:-Y}"
  else
    read -r -p "${prompt} [y/N]: " resp
    resp="${resp:-N}"
  fi
  case "$resp" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

check_child_script() {
  local f="$1"
  if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
    log_error "$f not found in $SCRIPT_DIR"; exit 1
  fi
}

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

get_installation_choice() {
  local choice
  while true; do
    read -r -p "Select installation method [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      1|2|3|0) echo "$choice"; return ;;
      *) log_error "Invalid selection. Please choose 1, 2, 3, or 0." ;;
    esac
  done
}

main() {
  parse_args "$@"
  show_banner
  show_installation_methods
  echo ""
  choice=$(get_installation_choice)
  echo ""
  case $choice in
    1) run_docker_install ;;
    2) run_devenv_install ;;
    3) run_symfony_cli_install ;;
    0) log_info "Installation cancelled."; exit 0 ;;
  esac
}

main "$@"
