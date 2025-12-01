#!/usr/bin/env bash
# safer installer wrapper to mitigate Composer extraction errors (zip/unzip / cache / perms)
set -euo pipefail
IFS=$'\n\t'

TARGET_DIR="${TARGET_DIR:-/var/www/html}"
PACKAGE="${PACKAGE:-shopware/production}"
VERSION="${VERSION:-latest}"   # or specific like v6.7.4.2
RETRIES=3
LOG_DIR="/tmp"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="${LOG_DIR}/shopware-create-${TIMESTAMP}.log"

# Helpers
info(){ echo -e "[INFO] $*"; }
warn(){ echo -e "[WARN] $*"; }
err(){ echo -e "[ERROR] $*" >&2; }
die(){ err "$*"; exit 1; }

# Basic checks
info "Checking PHP & tooling..."
php -v 2>/dev/null || die "php not found in PATH"
if ! php -m | grep -qi '^zip$'; then
  warn "php zip extension not present (php -m lacks 'zip'). Composer may fail extracting archives."
  warn "Install php-zip (e.g. apt-get install php-zip) or ensure zip support is available."
fi
if ! command -v unzip >/dev/null 2>&1; then
  warn "unzip binary not found. Composer can still use php-zip, but having 'unzip' is recommended."
fi

info "Checking target directory: ${TARGET_DIR}"
if [[ -e "${TARGET_DIR}" && ! -d "${TARGET_DIR}" ]]; then
  die "Target exists but is not a directory: ${TARGET_DIR}"
fi

# Ensure writable (if not, prompt to fix)
if [[ -d "${TARGET_DIR}" ]]; then
  if [[ ! -w "${TARGET_DIR}" ]]; then
    warn "Target directory ${TARGET_DIR} is not writable by $(id -un)."
    read -r -p "Attempt to chown ${TARGET_DIR} to $(id -un)? [y/N]: " yn
    yn="${yn:-N}"
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      sudo chown -R "$(id -un):$(id -gn)" "${TARGET_DIR}"
      info "Changed owner of ${TARGET_DIR} to $(id -un)"
    else
      die "Cannot proceed without write access to ${TARGET_DIR}."
    fi
  fi
else
  info "Creating ${TARGET_DIR} as it does not exist."
  sudo mkdir -p "${TARGET_DIR}"
  sudo chown "$(id -un):$(id -gn)" "${TARGET_DIR}"
fi

# Check disk space/inodes
df -h "${TARGET_DIR}" | tee -a "${LOG_FILE}"
df -i "${TARGET_DIR}" | tee -a "${LOG_FILE}"

# Clear composer cache first (fixes corrupted zip)
info "Clearing Composer cache..."
composer clear-cache 2>&1 | tee -a "${LOG_FILE}"

# Try create-project with retries
attempt_create() {
  local attempt="$1"
  info "Composer create-project attempt ${attempt}/${RETRIES} (no scripts, prefer-dist)..."
  set +e
  composer create-project "${PACKAGE}" . --prefer-dist --no-progress --no-scripts -vvv 2>&1 | tee -a "${LOG_FILE}"
  local rc=$?
  set -e
  return $rc
}

attempt_create_prefersource() {
  info "Composer create-project with --prefer-source (attempting git clones instead of zips)..."
  set +e
  composer create-project "${PACKAGE}" . --prefer-source --no-progress -vvv 2>&1 | tee -a "${LOG_FILE}"
  local rc=$?
  set -e
  return $rc
}

# Work in a temp directory to avoid half-created installs on failure
TMPDIR="$(mktemp -d /tmp/shopware-create.XXXXXX)"
info "Using temporary build dir: ${TMPDIR}"
cd "${TMPDIR}"

success=false
for i in $(seq 1 "${RETRIES}"); do
  # clear cache between attempts to avoid stale corrupted artifacts
  composer clear-cache 2>&1 | tee -a "${LOG_FILE}"
  if attempt_create "$i"; then
    success=true
    break
  fi
  warn "create-project failed on attempt ${i}. Retrying..."
done

# If still failing, try prefer-source once
if [[ "$success" != "true" ]]; then
  warn "create-project failed with prefer-dist. Trying --prefer-source to avoid zip extraction problems..."
  composer clear-cache 2>&1 | tee -a "${LOG_FILE}"
  if attempt_create_prefersource; then
    success=true
  fi
fi

# If still failing, try creating bare repo then require the specific package to isolate package failure
if [[ "$success" != "true" ]]; then
  warn "Still failing. Trying isolated require for potentially problematic package(s)..."
  composer clear-cache 2>&1 | tee -a "${LOG_FILE}"
  # minimal composer init then require package
  mkdir -p "${TMPDIR}/isolated"
  cd "${TMPDIR}/isolated"
  composer init --name=tmp/shopware-test --no-interaction 2>&1 | tee -a "${LOG_FILE}" || true
  set +e
  composer require "${PACKAGE}" --prefer-dist --no-progress -vvv 2>&1 | tee -a "${LOG_FILE}"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    info "Isolated require succeeded; moving files into place."
    # move to TMPDIR root for final copy
    cd "${TMPDIR}"
    rm -rf ./*
    mv isolated/* . || true
    success=true
  else
    warn "Isolated require failed (see ${LOG_FILE})."
  fi
fi

# Finalize: move into target if success
if [[ "$success" == "true" ]]; then
  info "Create-project succeeded in ${TMPDIR}. Moving into ${TARGET_DIR}..."
  # Move contents to target atomically (preserve perms). Back up existing if present.
  BACKUP="${TARGET_DIR}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  if [[ -n "$(ls -A "${TARGET_DIR}" 2>/dev/null || true)" ]]; then
    info "Back up existing ${TARGET_DIR} to ${BACKUP}"
    sudo mv "${TARGET_DIR}" "${BACKUP}"
  fi
  sudo mkdir -p "${TARGET_DIR}"
  sudo chown "$(id -un):$(id -gn)" "${TARGET_DIR}"
  # Move contents
  # Use rsync if available for safe copy, fall back to mv
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' "${TMPDIR}/" "${TARGET_DIR}/" 2>&1 | tee -a "${LOG_FILE}"
  else
    mv "${TMPDIR}"/* "${TARGET_DIR}/" 2>&1 | tee -a "${LOG_FILE}" || true
  fi
  info "Files moved to ${TARGET_DIR}."
  info "Running composer install (with scripts) in ${TARGET_DIR} to finalize..."
  cd "${TARGET_DIR}"
  composer install --no-progress -vvv 2>&1 | tee -a "${LOG_FILE}" || warn "composer install returned non-zero (check ${LOG_FILE})"
  info "Installation finished. Logs: ${LOG_FILE}"
  exit 0
else
  err "All automated attempts failed. Logs are in ${LOG_FILE}."
  err "Next steps (manual): inspect the log and follow earlier suggestions (check php zip, unzip, disk, permissions)."
  err "If you'd like, paste the last 200 lines of ${LOG_FILE} here and I will analyze them."
  exit 1
fi
