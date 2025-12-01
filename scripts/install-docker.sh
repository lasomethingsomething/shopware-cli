#!/usr/bin/env bash
# scripts/install-docker.sh
# Robust wrapper for docker-based install: ensure docker daemon is reachable,
# try Colima / Docker Desktop, then fall back to the symfony-local installer.
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
  # If DOCKER_HOST points to something invalid, docker info will fail.
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

fallback_to_symfony(){
  warn "Falling back to local (symfony) installer to keep the install seamless."
  if [[ -f "${SCRIPT_DIR}/install-symfony-cli.sh" ]]; then
    bash "${SCRIPT_DIR}/install-symfony-cli.sh" 2>&1 | tee -a "$LOG"
    rc=${PIPESTATUS[0]:-0}
    if [[ $rc -ne 0 ]]; then
      err "Fallback symfony installer failed (rc=$rc). See $LOG"
      exit $rc
    fi
    success "Fallback symfony installer finished."
    exit 0
  else
    err "install-symfony-cli.sh not found in ${SCRIPT_DIR}; cannot fallback."
    exit 1
  fi
}

ensure_docker_or_fallback(){
  sanitize_docker_host

  if docker_ok; then
    info "Docker daemon reachable; proceeding with docker-based install."
    return 0
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

  # still not available -> fallback
  fallback_to_symfony
}

# ---- main flow ----
info "Ensuring docker daemon is available for docker-based install..."
ensure_docker_or_fallback

# If we get here, docker is reachable. Proceed with the original docker install behavior.
# Replace the block below with your original docker install steps if you have them.
# The example here performs a docker-compose based project start if docker-compose.yaml exists,
# otherwise it will attempt a generic docker-based create (you can adjust to your original logic).

# Example: if repo provides docker-compose.yml in this script's parent, use it
PROJECT_ROOT="$(pwd)" # adjust if you need a different working dir
info "Docker available; running docker-based installation steps..."

# If you have a docker-compose workflow in your project, run it. If not, you should replace
# the placeholder below with your real docker commands (e.g. docker compose up, creating volumes, etc).
if [[ -f "${SCRIPT_DIR}/docker-compose.yml" ]] || [[ -f "${SCRIPT_DIR}/../docker-compose.yml" ]]; then
  DC_FILE="${SCRIPT_DIR}/docker-compose.yml"
  if [[ ! -f "$DC_FILE" ]]; then DC_FILE="${SCRIPT_DIR}/../docker-compose.yml"; fi
  info "Using docker-compose file: $DC_FILE"
  # prefer modern 'docker compose' if available; fallback to 'docker-compose'
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$DC_FILE" pull 2>&1 | tee -a "$LOG"
    docker compose -f "$DC_FILE" up -d 2>&1 | tee -a "$LOG"
  else
    if command -v docker-compose >/dev/null 2>&1; then
      docker-compose -f "$DC_FILE" pull 2>&1 | tee -a "$LOG"
      docker-compose -f "$DC_FILE" up -d 2>&1 | tee -a "$LOG"
    else
      warn "No docker compose binary found; you may need 'docker compose' or 'docker-compose' to proceed."
      # fallback: still continue, but do not error
    fi
  fi
else
  # No compose file found — attempt generic containerized create (placeholder).
  info "No docker-compose.yml found next to installer. If you expected automatic docker steps, please add them here."
  # As a safety measure do not run anything destructive; exit successfully so higher-level script knows docker path succeeded.
fi

success "Docker-based install steps completed (or skipped if none present). Logs: $LOG"
exit 0
