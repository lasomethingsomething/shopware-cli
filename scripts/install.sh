#!/usr/bin/env bash
# scripts/install.sh
# Auto-install wrapper: prefer Docker, try Colima / Docker Desktop, fallback to symfony installer.
# Designed to be non-interactive so `curl ... && chmod +x install.sh && ./install.sh` is smooth.
set -euo pipefail
IFS=$'\n\t'

LOG="/tmp/shopware-install-auto.$(date -u +%Y%m%dT%H%M%SZ).log"
DOCKER_WAIT_SECS=40
COLIMA_WAIT_SECS=30
INSTALL_METHOD="${INSTALL_METHOD:-}"

info(){ printf '%s %s\n' "[INFO]" "$*" | tee -a "$LOG"; }
warn(){ printf '%s %s\n' "[WARN]" "$*" | tee -a "$LOG"; }
err(){ printf '%s %s\n' "[ERROR]" "$*" | tee -a "$LOG" >&2; }
success(){ printf '%s %s\n' "[SUCCESS]" "$*" | tee -a "$LOG"; }

usage(){
  cat <<_USAGE_
Usage: $0 [--method docker|devenv|symfony]
If docker is available it will be used; otherwise script will try Colima / Docker Desktop and then fall back to symfony.
Environment variable: INSTALL_METHOD
_USAGE_
}

# small arg parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    --method|-m) INSTALL_METHOD="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

# docker_ok: returns 0 if docker client can talk to daemon
docker_ok(){
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

# Try starting Colima (if present) and wait for docker
try_start_colima(){
  if command -v colima >/dev/null 2>&1; then
    info "Colima detected. Starting colima..."
    # start may print to stdout; don't fail if start returns non-zero
    colima start 2>&1 | tee -a "$LOG" || true
    info "Waiting up to ${COLIMA_WAIT_SECS}s for docker availability..."
    local end=$((SECONDS + COLIMA_WAIT_SECS))
    while [[ $SECONDS -lt $end ]]; do
      if docker_ok; then info "Docker reachable via Colima."; return 0; fi
      sleep 1
    done
    warn "Docker not reachable after starting Colima."
    return 1
  fi
  return 1
}

# Try starting Docker Desktop (macOS) and wait for docker
try_start_docker_desktop(){
  if [[ "$(uname -s)" == "Darwin" ]] && [[ -d "/Applications/Docker.app" ]]; then
    info "Attempting to open Docker Desktop..."
    open -a Docker 2>/dev/null || true
    info "Waiting up to ${DOCKER_WAIT_SECS}s for docker daemon..."
    local end=$((SECONDS + DOCKER_WAIT_SECS))
    while [[ $SECONDS -lt $end ]]; do
      if docker_ok; then info "Docker daemon reachable."; return 0; fi
      sleep 1
    done
    warn "Docker Desktop didn't become reachable in ${DOCKER_WAIT_SECS}s."
    return 1
  fi
  return 1
}

# Decide which installer to run
select_install_method(){
  # honor explicit request
  if [[ -n "${INSTALL_METHOD}" ]]; then
    info "INSTALL_METHOD forced to '${INSTALL_METHOD}'"
    echo "$INSTALL_METHOD"
    return
  fi

  # prefer docker if available
  if docker_ok; then
    echo "docker"
    return
  fi

  # try colima
  if try_start_colima; then
    echo "docker"
    return
  fi

  # try docker desktop (macOS)
  if try_start_docker_desktop; then
    echo "docker"
    return
  fi

  # fallback to symfony/local install (non-docker)
  warn "Docker not available — falling back to 'symfony' (local) installation method."
  echo "symfony"
}

METHOD="$(select_install_method)"
info "Chosen installation method: ${METHOD}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$METHOD" in
  docker)
    info "Running docker installer..."
    if [[ -f "${SCRIPT_DIR}/install-docker.sh" ]]; then
      bash "${SCRIPT_DIR}/install-docker.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "Docker installer failed (rc=$rc). See $LOG"; exit $rc; fi
      success "Docker installer finished."
    else
      err "install-docker.sh not found in ${SCRIPT_DIR}"; exit 1
    fi
    ;;
  devenv)
    info "Running devenv installer..."
    if [[ -f "${SCRIPT_DIR}/install-devenv.sh" ]]; then
      bash "${SCRIPT_DIR}/install-devenv.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "Devenv installer failed (rc=$rc). See $LOG"; exit $rc; fi
      success "Devenv installer finished."
    else
      err "install-devenv.sh not found in ${SCRIPT_DIR}"; exit 1
    fi
    ;;
  symfony)
    info "Running symfony/local installer..."
    if [[ -f "${SCRIPT_DIR}/install-symfony-cli.sh" ]]; then
      bash "${SCRIPT_DIR}/install-symfony-cli.sh" 2>&1 | tee -a "$LOG"
      rc=${PIPESTATUS[0]:-0}
      if [[ $rc -ne 0 ]]; then err "Symfony installer failed (rc=$rc). See $LOG"; exit $rc; fi
      success "Symfony installer
