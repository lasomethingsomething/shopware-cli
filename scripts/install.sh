#!/usr/bin/env bash
# scripts/install.sh
# Installer entrypoint with runtime choice: docker, podman, colima, orbstack, symfony, devenv
# Non-destructive start attempts. No scrollback-clearing sequences.
set -euo pipefail
IFS=$'\n\t'

LOG="/tmp/shopware-install.$(date -u +%Y%m%dT%H%M%SZ).log"
WAIT_SECS_DEFAULT=40
AUTO_YES="${AUTO_YES:-false}"
INSTALL_METHOD="${INSTALL_METHOD:-}"  # override via env
INTERACTIVE=false

# Helpers
info(){ printf '%s %s\n' "[INFO]" "$*" | tee -a "$LOG"; }
warn(){ printf '%s %s\n' "[WARN]" "$*" | tee -a "$LOG"; }
err(){ printf '%s %s\n' "[ERROR]" "$*" | tee -a "$LOG" >&2; }
success(){ printf '%s %s\n' "[SUCCESS]" "$*" | tee -a "$LOG"; }

# parse args: --method/-m, --yes/-y, --help
while [[ $# -gt 0 ]]; do
  case "$1" in
    --method|-m)
      INSTALL_METHOD="${2:-}"; shift 2 ;;
    --yes|-y)
      AUTO_YES=true; shift ;;
    --help|-h)
      cat <<EOF
Usage: $0 [--method docker|podman|colima|orbstack|symfony|devenv] [--yes]
Environment variable: INSTALL_METHOD, AUTO_YES
If no method is set, script will try to auto-detect. In interactive TTY a menu will be shown.
EOF
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Detect interactive terminal
if [[ -t 0 && -t 1 ]]; then INTERACTIVE=true; fi

# --- Runtime checks & starters ---

docker_ok() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

start_docker_desktop() {
  if [[ "$(uname -s)" == "Darwin" ]] && [[ -d "/Applications/Docker.app" ]]; then
    info "Starting Docker Desktop..."
    open -a Docker 2>/dev/null || true
    local end=$((SECONDS + WAIT_SECS_DEFAULT))
    while [[ $SECONDS -lt $end ]]; do
      if docker_ok; then info "Docker is reachable."; return 0; fi
      sleep 1
    done
    warn "Docker Desktop did not become reachable in ${WAIT_SECS_DEFAULT}s."
    return 1
  fi
  return 1
}

podman_ok() {
  command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1
}

start_podman_machine() {
  if command -v podman >/dev/null 2>&1; then
    # Podman on macOS can use 'podman machine start'
    if podman machine list >/dev/null 2>&1 2>/dev/null; then
      info "Starting podman machine..."
      podman machine start 2>&1 | tee -a "$LOG" || true
      local end=$((SECONDS + WAIT_SECS_DEFAULT))
      while [[ $SECONDS -lt $end ]]; do
        if podman_ok; then info "Podman is reachable."; return 0; fi
        sleep 1
      done
      warn "Podman machine did not become reachable in ${WAIT_SECS_DEFAULT}s."
      return 1
    fi
  fi
  return 1
}

colima_ok() {
  command -v colima >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

start_colima() {
  if command -v colima >/dev/null 2>&1; then
    info "Starting Colima..."
    colima start 2>&1 | tee -a "$LOG" || true
    local end=$((SECONDS + WAIT_SECS_DEFAULT))
    while [[ $SECONDS -lt $end ]]; do
      if colima_ok; then info "Docker reachable via Colima."; return 0; fi
      sleep 1
    done
    warn "Colima did not become reachable in ${WAIT_SECS_DEFAULT}s."
    return 1
  fi
  return 1
}

orbstack_ok() {
  # orbstack has CLI 'orbstack' or its daemon exposes docker socket; try 'orbstack status' if available
  if command -v orbstack >/dev/null 2>&1; then
    if orbstack status >/dev/null 2>&1; then
      # orbstack also makes Docker-compatible socket available; test docker info
      docker info >/dev/null 2>&1 && return 0 || return 0
    fi
  fi
  # As fallback check app presence on macOS
  if [[ "$(uname -s)" == "Darwin" && -d "/Applications/Orbstack.app" ]]; then
    # docker info may work if Orbstack exposes socket
    docker info >/dev/null 2>&1 && return 0 || return 1
  fi
  return 1
}

start_orbstack() {
  if command -v orbstack >/dev/null 2>&1; then
    info "Starting Orbstack (via CLI)..."
    # orbstack start/launch may exist
    orbstack start 2>&1 | tee -a "$LOG" || true
    local end=$((SECONDS + WAIT_SECS_DEFAULT))
    while [[ $SECONDS -lt $end ]]; do
      if orbstack_ok; then info "Orbstack reachable."; return 0; fi
      sleep 1
    done
    warn "Orbstack CLI did not make runtime reachable in ${WAIT_SECS_DEFAULT}s."
    return 1
  fi
  if [[ "$(uname -s)" == "Darwin" && -d "/Applications/Orbstack.app" ]]; then
    info "Opening Orbstack.app..."
    open -a Orbstack 2>/dev/null || true
    local end=$((SECONDS + WAIT_SECS_DEFAULT))
    while [[ $SECONDS -lt $end ]]; do
      if orbstack_ok; then info "Orbstack is reachable."; return 0; fi
      sleep 1
    done
    warn "Orbstack.app did not make runtime reachable in ${WAIT_SECS_DEFAULT}s."
    return 1
  fi
  return 1
}

# --- selection logic ---

valid_method() {
  case "$1" in docker|podman|colima|orbstack|symfony|devenv) return 0 ;; *) return 1 ;; esac
}

choose_method_interactive() {
  cat <<EOF
Choose container/runtime method (type number and Enter):
  1) docker    - Docker Desktop / engine
  2) podman    - Podman (podman machine on mac)
  3) colima    - Colima (macOS)
  4) orbstack  - Orbstack (macOS)
  5) symfony   - Local PHP + Composer (no containers)
  6) devenv    - Developer environment (nix etc)
  0) exit
EOF
  while true; do
    read -r -p "Select [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      1) echo docker; return ;;
      2) echo podman; return ;;
      3) echo colima; return ;;
      4) echo orbstack; return ;;
      5) echo symfony; return ;;
      6) echo devenv; return ;;
      0) echo exit; return ;;
      *) echo "Invalid choice" ;;
    esac
  done
}

# Auto-detect order (when not forced by user)
auto_detect_method() {
  # try docker first
  if docker_ok; then echo docker; return; fi
  # try podman
  if podman_ok; then echo podman; return; fi
  # try colima (start attempt)
  if start_colima; then echo docker; return; fi
  # try orbstack (start attempt)
  if start_orbstack; then echo docker; return; fi
  # try to start Docker Desktop
  if start_docker_desktop; then echo docker; return; fi
  # try starting podman machine
  if start_podman_machine; then echo podman; return; fi
  # nothing available → fallback to local
  echo symfony
}

# If INSTALL_METHOD forced, validate
if [[ -n "${INSTALL_METHOD}" ]]; then
  INSTALL_METHOD="${INSTALL_METHOD,,}"  # to lowercase
  if ! valid_method "$INSTALL_METHOD"; then
    err "Invalid INSTALL_METHOD: $INSTALL_METHOD"
    exit 1
  fi
  CHOSEN="$INSTALL_METHOD"
else
  if $INTERACTIVE; then
    CHOSEN="$(choose_method_interactive)"
    if [[ "$CHOSEN" == "exit" ]]; then info "User cancelled."; exit 0; fi
  else
    CHOSEN="$(auto_detect_method)"
  fi
fi

info "Chosen method: $CHOSEN"

# If chosen is a container runtime that requires starting, ensure it's reachable:
case "$CHOSEN" in
  docker)
    if ! docker_ok; then
      info "docker not currently reachable; will try starting Docker Desktop."
      if ! start_docker_desktop; then
        warn "Docker Desktop startup failed or timed out; falling back to symfony"
        CHOSEN="symfony"
      fi
    fi
    ;;
  podman)
    if ! podman_ok; then
      info "podman not reachable; attempting to start podman machine..."
      if ! start_podman_machine; then
        warn "Podman start failed; falling back to symfony"
        CHOSEN="symfony"
      fi
    fi
    ;;
  colima)
    # colima uses Docker socket, ensure start
    if ! colima_ok; then
      info "Colima not reachable; attempting to start Colima..."
      if ! start_colima; then
        warn "Colima start failed; falling back to symfony"
        CHOSEN="symfony"
      fi
    fi
    ;;
  orbstack)
    if ! orbstack_ok; then
      info "Orbstack not reachable; attempting to start Orbstack..."
      if ! start_orbstack; then
        warn "Orbstack start failed; falling back to symfony"
        CHOSEN="symfony"
      fi
    fi
    ;;
  symfony|devenv)
    # local methods — nothing to start
    ;;
  *)
    err "Unsupported method after selection: $CHOSEN"
    exit 1
    ;;
esac

info "Final installer method: $CHOSEN"

# Dispatch to real installers (scripts must exist next to this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$CHOSEN" in
  docker)
    if [[ -f "${SCRIPT_DIR}/install-docker.sh" ]]; then
      bash "${SCRIPT_DIR}/install-docker.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "install-docker.sh failed (rc=$rc)"; exit $rc; fi
    else
      err "install-docker.sh not found"; exit 1
    fi
    ;;
  podman)
    if [[ -f "${SCRIPT_DIR}/install-podman.sh" ]]; then
      bash "${SCRIPT_DIR}/install-podman.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "install-podman.sh failed (rc=$rc)"; exit $rc; fi
    else
      err "install-podman.sh not found"; exit 1
    fi
    ;;
  colima)
    # reuse docker installer because colima provides a docker socket
    if [[ -f "${SCRIPT_DIR}/install-docker.sh" ]]; then
      bash "${SCRIPT_DIR}/install-docker.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "install-docker.sh failed (rc=$rc)"; exit $rc; fi
    else
      err "install-docker.sh not found"; exit 1
    fi
    ;;
  orbstack)
    # Orbstack provides docker-compatible socket; reuse docker flow
    if [[ -f "${SCRIPT_DIR}/install-docker.sh" ]]; then
      bash "${SCRIPT_DIR}/install-docker.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "install-docker.sh failed (rc=$rc)"; exit $rc; fi
    else
      err "install-docker.sh not found"; exit 1
    fi
    ;;
  symfony)
    if [[ -f "${SCRIPT_DIR}/install-symfony-cli.sh" ]]; then
      bash "${SCRIPT_DIR}/install-symfony-cli.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "install-symfony-cli.sh failed (rc=$rc)"; exit $rc; fi
    else
      err "install-symfony-cli.sh not found"; exit 1
    fi
    ;;
  devenv)
    if [[ -f "${SCRIPT_DIR}/install-devenv.sh" ]]; then
      bash "${SCRIPT_DIR}/install-devenv.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "install-devenv.sh failed (rc=$rc)"; exit $rc; fi
    else
      err "install-devenv.sh not found"; exit 1
    fi
    ;;
esac

success "All done. Logs: $LOG"
exit 0
