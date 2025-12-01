#!/usr/bin/env bash
# scripts/install-docker.sh
# Robust wrapper for docker-based install: ensure docker daemon is reachable,
# try Colima / Docker Desktop if needed.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="/tmp/shopware-install-docker.$(date -u +%Y%m%dT%H%M%SZ).log"
DOCKER_WAIT_SECS=40
COLIMA_WAIT_SECS=30

info(){ printf '%s %s\n' "[INFO]" "$*" | tee -a "$LOG"; }
warn(){ printf '%s %s\n' "[WARN]" "$*" | tee -a "$LOG"; }
err(){ printf '%s %s\n' "[ERROR]" "$*" | tee -a "$LOG" >&2; }
success(){ printf '%s %s\n' "[SUCCESS]" "$*" | tee -a "$LOG"; }

# Check docker daemon connectivity
docker_ok(){
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# If DOCKER_HOST points at a user socket that doesn't exist, unset it for this session
sanitize_docker_host(){
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    # If DOCKER_HOST looks like unix:///... and socket doesn't exist, unset it temporarily
    if [[ "$DOCKER_HOST" == unix://* ]]; then
      sock="${DOCKER_HOST#unix://}"
      if [[ ! -S "$sock" ]]; then
        warn "DOCKER_HOST=$DOCKER_HOST points to missing socket $sock — unsetting DOCKER_HOST for this session"
        unset DOCKER_HOST
      fi
    fi
  fi
}

try_start_colima(){
  if command -v colima >/dev/null 2>&1; then
    info "Colima detected. Starting colima..."
    colima start 2>&1 | tee -a "$LOG" || true
    info "Waiting up to ${COLIMA_WAIT_SECS}s for docker availability..."
    local end=$((SECONDS + COLIMA_WAIT_SECS))
    while [[ $SECONDS -lt $end ]]; do
      sanitize_docker_host
      if docker_ok; then info "Docker reachable via Colima."; return 0; fi
      sleep 1
    done
    warn "Docker not reachable after starting Colima."
    return 1
  fi
  return 1
}

try_start_docker_desktop(){
  if [[ "$(uname -s)" == "Darwin" ]] && [[ -d "/Applications/Docker.app" ]]; then
    info "Attempting to open Docker Desktop..."
    open -a Docker 2>/dev/null || true
    info "Waiting up to ${DOCKER_WAIT_SECS}s for docker daemon..."
    local end=$((SECONDS + DOCKER_WAIT_SECS))
    while [[ $SECONDS -lt $end ]]; do
      sanitize_docker_host
      if docker_ok; then info "Docker daemon reachable."; return 0; fi
      sleep 1
    done
    warn "Docker Desktop didn't become reachable in ${DOCKER_WAIT_SECS}s."
    return 1
  fi
  return 1
}

ensure_docker_available(){
  sanitize_docker_host

  if docker_ok; then
    info "Docker daemon reachable; proceeding with docker-based install."
    return 0
  fi

  # Check if we're being called with NO_FALLBACK flag from the master installer
  if [[ "${SHOPWARE_INSTALL_NO_FALLBACK:-}" == "1" ]]; then
    err "Docker is not available and automatic fallback is disabled."
    err "Please start Docker and try again, or choose a different installation method."
    exit 1
  fi

  info "Docker daemon not reachable. Will try to start Colima or Docker Desktop (non-interactive attempts)."

  # Try Colima first
  if try_start_colima; then
    return 0
  fi

  # Try Docker Desktop (macOS)
  if try_start_docker_desktop; then
    return 0
  fi

  # If we still can't get Docker running, exit with error
  err "Unable to start Docker automatically."
  err "Please start Docker manually:"
  err "  • macOS: Open Docker Desktop from Applications or run 'colima start'"
  err "  • Linux: sudo systemctl start docker"
  err "  • Windows: Start Docker Desktop"
  err ""
  err "Then run this installer again."
  exit 1
}

# ---- main flow ----
info "Ensuring docker daemon is available for docker-based install..."
ensure_docker_available

# If we get here, docker is reachable. Proceed with the original docker install behavior.
PROJECT_ROOT="$(pwd)"
info "Docker available; running docker-based installation steps..."

# Check for docker-compose file
if [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]] || [[ -f "${SCRIPT_DIR}/../docker-compose.yml" ]]; then
  DC_FILE="${SCRIPT_DIR}/docker-compose.yml"
  if [[ ! -f "$DC_FILE" ]]; then DC_FILE="${SCRIPT_DIR}/../docker-compose.yml"; fi
  info "Using docker-compose file: $DC_FILE"
  
  # prefer modern 'docker compose' if available; fallback to 'docker-compose'
  if docker compose version >/dev/null 2>&1; then
    info "Pulling Docker images..."
    docker compose -f "$DC_FILE" pull 2>&1 | tee -a "$LOG"
    info "Starting containers..."
    docker compose -f "$DC_FILE" up -d 2>&1 | tee -a "$LOG"
    success "Docker containers started successfully!"
  else
    if command -v docker-compose >/dev/null 2>&1; then
      info "Pulling Docker images..."
      docker-compose -f "$DC_FILE" pull 2>&1 | tee -a "$LOG"
      info "Starting containers..."
      docker-compose -f "$DC_FILE" up -d 2>&1 | tee -a "$LOG"
      success "Docker containers started successfully!"
    else
      err "No docker compose binary found. Please install 'docker compose' plugin or 'docker-compose'."
      exit 1
    fi
  fi
  
  # Show running containers
  info "Running containers:"
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$DC_FILE" ps
  else
    docker-compose -f "$DC_FILE" ps
  fi
  
else
  # No compose file found
  warn "No docker-compose.yml found next to installer or in parent directory."
  info "To use Docker installation, please ensure you have a docker-compose.yml file."
  info "You can create one or place this installer in your project directory."
  exit 1
fi

success "Docker-based install completed successfully! Logs: $LOG"
echo ""
info "Next steps:"
info "  • Check container status: docker compose ps"
info "  • View logs: docker compose logs -f"
info "  • Stop containers: docker compose down"

exit 0
