#!/usr/bin/env bash
set -Eeuo pipefail

XRAY_DIR="/etc/xray"
TARGET="${XRAY_DIR}/config.json"
CRT="${XRAY_DIR}/xray.crt"
KEY="${XRAY_DIR}/xray.key"
XRAY_BIN="/usr/local/bin/xray"
SERVICE="xray"

# Backup buatan script ini sengaja memakai prefix berbeda,
# agar TIDAK ikut dianggap kandidat restore utama.
SCRIPT_BACKUP_PREFIX="config.json.pre-restore"
TS="$(date '+%Y-%m-%d-%H%M%S')"

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

err() {
  echo "[ERROR] $*" >&2
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Script ini harus dijalankan sebagai root."
    exit 1
  fi
}

require_file() {
  local f="$1"
  if [[ ! -e "$f" ]]; then
    err "File tidak ditemukan: $f"
    exit 1
  fi
}

find_latest_restore_backup() {
  find "$XRAY_DIR" -maxdepth 1 -type f -name 'config.json.bak.*' -printf '%T@ %p\n' \
    | sort -nr \
    | head -n1 \
    | cut -d' ' -f2-
}

backup_current_config() {
  if [[ -f "$TARGET" ]]; then
    local backup_path="${XRAY_DIR}/${SCRIPT_BACKUP_PREFIX}.${TS}"
    cp -a "$TARGET" "$backup_path"
    log "Backup config lama disimpan ke: $backup_path"
  else
    warn "config.json aktif tidak ada, lewati backup config lama."
  fi
}

restore_latest_backup() {
  local latest_backup="$1"
  cp -f "$latest_backup" "$TARGET"
  log "Restore selesai dari backup terbaru: $latest_backup"
}

fix_permissions() {
  chgrp www-data "$TARGET" "$CRT" "$KEY"
  chmod 640 "$TARGET" "$CRT" "$KEY"
  log "Permission diperbarui:"
  ls -l "$TARGET" "$CRT" "$KEY"
}

test_config() {
  log "Menjalankan test konfigurasi..."
  "$XRAY_BIN" run -test -c "$TARGET"
  log "Test konfigurasi: OK"
}

restart_service() {
  log "Reset status gagal systemd..."
  systemctl reset-failed "$SERVICE" || true

  log "Restart service $SERVICE..."
  systemctl restart "$SERVICE"

  log "Status service:"
  systemctl status "$SERVICE" --no-pager -l
}

main() {
  require_root
  require_file "$XRAY_BIN"
  require_file "$CRT"
  require_file "$KEY"

  local latest_backup
  latest_backup="$(find_latest_restore_backup)"

  if [[ -z "${latest_backup:-}" ]]; then
    err "Tidak ditemukan file backup restore dengan pola: ${XRAY_DIR}/config.json.bak.*"
    exit 1
  fi

  log "Backup restore terbaru yang ditemukan: $latest_backup"

  backup_current_config
  restore_latest_backup "$latest_backup"
  fix_permissions
  test_config
  restart_service

  log "Selesai."
}

main "$@"