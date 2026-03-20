#!/usr/bin/env bash
# INSTALLER PRODUCTION STABLE
# Debian 9–13 / Ubuntu 16.04–24+
# Enhanced: System-wide blocking of GitHub user "diah082" (case-insensitive)
# Blocks: wget, curl, git (clone, pull, fetch, remote, etc.)

set -Eeo pipefail

SESSION_NAME="install_setup"
WORKDIR="/root/install_setup"
LOGFILE="/var/log/install_setup.log"
TZ="Asia/Jakarta"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

BLOCKED_USER="diah082"

########################################
# UTIL
########################################

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || fail "Harus root"
}

have() { command -v "$1" >/dev/null 2>&1; }

apt_quiet() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y "$@" >/dev/null 2>&1 || fail "apt install $* gagal"
}

########################################
# BLOCK URL RAW GITHUB USER DIAH082 (script-internal)
########################################

is_blocked_url() {
  local url="${1:-}"
  local lower
  lower="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
    *"github.com/$BLOCKED_USER"*)
      return 0 ;;
    *"raw.githubusercontent.com/$BLOCKED_USER"*)
      return 0 ;;
    *"gist.github.com/$BLOCKED_USER"*)
      return 0 ;;
    *"api.github.com/users/$BLOCKED_USER"*)
      return 0 ;;
    *"github.com:$BLOCKED_USER"*)   # SSH git
      return 0 ;;
    *"github.com/$BLOCKED_USER/"*)  # Additional coverage
      return 0 ;;
    *)
      return 1 ;;
  esac
}

guard_url() {
  local url="${1:-}"
  if is_blocked_url "$url"; then
    fail "URL diblokir oleh policy lokal: $url"
  fi
}

########################################
# DOWNLOAD DENGAN RETRY
########################################

download() {
  local url="$1"
  local out="$2"

  guard_url "$url"

  for i in {1..3}; do
    if curl -fsSL "$url" -o "$out"; then
      chmod +x "$out"
      return 0
    fi
    log "Retry download ($i)..."
    sleep 2
  done

  fail "Download gagal: $url"
}

########################################
# RUN SCRIPT AMAN
########################################

run_script() {
  local name="$1"
  local url="$2"
  local file="$WORKDIR/$name.sh"

  log "Download $name"
  download "$url" "$file"

  log "Run $name"
  bash "$file" || fail "$name gagal"

  rm -f "$file"
}

########################################
# CREATE WRAPPERS
########################################

create_wrapper() {
  local binary="$1"
  local wrapper_content="$2"
  local orig="${binary}.orig"

  if [ ! -x "$binary" ]; then
    log "Binary tidak ditemukan atau tidak bisa dieksekusi: $binary"
    return 1
  fi

  # Backup original jika belum ada
  if [ ! -f "$orig" ]; then
    mv "$binary" "$orig" || {
      log "Gagal memindahkan $binary ke $orig"
      return 1
    }
    log "Original $binary -> $orig"
  else
    log "Backup $orig sudah ada, tidak membuat ulang"
  fi

  # Tulis wrapper dan ganti placeholder %s dengan path original
  cat > "$binary" <<EOF
$wrapper_content
EOF
  sed -i "s|%s|${orig}|g" "$binary"
  chmod +x "$binary"
  log "Wrapper dipasang di $binary"
}

setup_block_wrappers() {
  log "Memasang wrapper sistem untuk curl, wget, dan git (blokir $BLOCKED_USER)"

  # -------------------------------------------------------------------
  # WRAPPER CURL
  # -------------------------------------------------------------------
  local curl_path
  for p in /usr/bin/curl /usr/local/bin/curl /bin/curl; do
    [ -x "$p" ] && curl_path="$p" && break
  done

  if [ -n "$curl_path" ]; then
    create_wrapper "$curl_path" "$(cat <<'CURL_WRAPPER'
#!/bin/bash
# Wrapper curl – memblokir akses ke GitHub user tertentu
ORIG_CURL="%s"
BLOCKED_USER="diah082"

is_blocked() {
    local url="$1"
    local lower
    lower="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *"github.com/$BLOCKED_USER"*)
            return 0 ;;
        *"raw.githubusercontent.com/$BLOCKED_USER"*)
            return 0 ;;
        *"gist.github.com/$BLOCKED_USER"*)
            return 0 ;;
        *"api.github.com/users/$BLOCKED_USER"*)
            return 0 ;;
        *"github.com:$BLOCKED_USER"*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]]; then
        if is_blocked "$arg"; then
            echo "ERROR: Akses ke $arg diblokir (user $BLOCKED_USER)" >&2
            exit 1
        fi
    fi
done

exec "$ORIG_CURL" "$@"
CURL_WRAPPER
)" || fail "Gagal membuat wrapper curl"
  else
    log "curl tidak ditemukan, lewati"
  fi

  # -------------------------------------------------------------------
  # WRAPPER WGET
  # -------------------------------------------------------------------
  local wget_path
  for p in /usr/bin/wget /usr/local/bin/wget /bin/wget; do
    [ -x "$p" ] && wget_path="$p" && break
  done

  if [ -n "$wget_path" ]; then
    create_wrapper "$wget_path" "$(cat <<'WGET_WRAPPER'
#!/bin/bash
# Wrapper wget – memblokir akses ke GitHub user tertentu
ORIG_WGET="%s"
BLOCKED_USER="diah082"

is_blocked() {
    local url="$1"
    local lower
    lower="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *"github.com/$BLOCKED_USER"*)
            return 0 ;;
        *"raw.githubusercontent.com/$BLOCKED_USER"*)
            return 0 ;;
        *"gist.github.com/$BLOCKED_USER"*)
            return 0 ;;
        *"api.github.com/users/$BLOCKED_USER"*)
            return 0 ;;
        *"github.com:$BLOCKED_USER"*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]]; then
        if is_blocked "$arg"; then
            echo "ERROR: Akses ke $arg diblokir (user $BLOCKED_USER)" >&2
            exit 1
        fi
    fi
done

exec "$ORIG_WGET" "$@"
WGET_WRAPPER
)" || fail "Gagal membuat wrapper wget"
  else
    log "wget tidak ditemukan, lewati"
  fi

  # -------------------------------------------------------------------
  # WRAPPER GIT
  # -------------------------------------------------------------------
  local git_path
  for p in /usr/bin/git /usr/local/bin/git /bin/git; do
    [ -x "$p" ] && git_path="$p" && break
  done

  if [ -n "$git_path" ]; then
    create_wrapper "$git_path" "$(cat <<'GIT_WRAPPER'
#!/bin/bash
# Wrapper git – memblokir akses ke repositori GitHub user tertentu
ORIG_GIT="%s"
BLOCKED_USER="diah082"

is_blocked_url() {
    local url="$1"
    local lower
    lower="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        *"github.com/$BLOCKED_USER"*)
            return 0 ;;
        *"github.com:$BLOCKED_USER"*)
            return 0 ;;
        *"raw.githubusercontent.com/$BLOCKED_USER"*)
            return 0 ;;
        *"gist.github.com/$BLOCKED_USER"*)
            return 0 ;;
        *"api.github.com/users/$BLOCKED_USER"*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Periksa semua argumen untuk URL atau remote
for arg in "$@"; do
    # Cek argumen yang berisi URL (https, http, git, ssh)
    if [[ "$arg" =~ ^(https?://|git@|ssh://) ]]; then
        if is_blocked_url "$arg"; then
            echo "ERROR: Akses ke $arg diblokir (user $BLOCKED_USER)" >&2
            exit 1
        fi
    fi
done

# Jalankan git asli
exec "$ORIG_GIT" "$@"
GIT_WRAPPER
)" || fail "Gagal membuat wrapper git"
  else
    log "git tidak ditemukan, lewati"
  fi
}

########################################
# VERIFIKASI BLOKIR
########################################

verify_blocking() {
  log "Verifikasi blokir akses ke user $BLOCKED_USER..."

  local test_url="https://raw.githubusercontent.com/Diah082/test/main/dummy.txt"
  local tmpfile="/tmp/block_test"

  # Coba dengan wget
  if have wget; then
    if wget -q --timeout=5 --tries=1 -O "$tmpfile" "$test_url" 2>/dev/null; then
      log "ERROR: wget masih bisa mengakses URL terblokir!"
      return 1
    else
      log "OK: wget berhasil diblokir."
    fi
  fi

  # Coba dengan curl
  if have curl; then
    if curl -fsSL --connect-timeout 5 --max-time 5 -o "$tmpfile" "$test_url" 2>/dev/null; then
      log "ERROR: curl masih bisa mengakses URL terblokir!"
      return 1
    else
      log "OK: curl berhasil diblokir."
    fi
  fi

  # Coba dengan git (clone ke direktori sementara)
  if have git; then
    local test_repo="https://github.com/Diah082/test.git"
    local clone_dir="/tmp/git_block_test"
    if git clone --depth 1 "$test_repo" "$clone_dir" &>/dev/null; then
      log "ERROR: git masih bisa mengclone repo terblokir!"
      rm -rf "$clone_dir"
      return 1
    else
      log "OK: git berhasil diblokir."
      rm -rf "$clone_dir"
    fi
  fi

  rm -f "$tmpfile"
  log "Verifikasi blokir SELESAI – semua OK"
  return 0
}

########################################
# RUNNER
########################################

runner() {
  log "===== RUN START ====="

  apt_quiet ca-certificates curl wget git
  apt_quiet chrony

  timedatectl set-timezone "$TZ" >/dev/null 2>&1 || true
  systemctl restart chrony >/dev/null 2>&1 || true

  mkdir -p "$WORKDIR"

  run_script kunci-ssh "$URL_KUNCI"
  run_script ubah-ssh "$URL_UBAH"
  run_script fix-profile "$URL_FIXP"

  log "===== RUN DONE ====="
}

########################################
# MONITOR SCREEN
########################################

wait_finish() {
  local spin='-\|/'
  local i=0

  printf "Sedang Proses Setup Install... "

  while true; do
    if grep -q "RUN DONE" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Setup Install... ✅ Selesai\n"
      return 0
    fi

    if ! screen -list | grep -q "$SESSION_NAME"; then
      sleep 1
      if grep -q "RUN DONE" "$LOGFILE"; then
        printf "\rSedang Proses Setup Install... ✅ Selesai\n"
        return 0
      fi

      printf "\rSedang Proses Setup Install... ❌ Gagal\n"
      tail -n 30 "$LOGFILE"
      return 1
    fi

    printf "\rSedang Proses Setup Install... %c" "${spin:i++%4:1}"
    sleep 0.2
  done
}

########################################
# MAIN
########################################

main() {
  require_root
  have apt-get || fail "apt tidak tersedia"

  apt_quiet screen

  mkdir -p "$WORKDIR"
  : > "$LOGFILE"

  cat > "$WORKDIR/runner.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeo pipefail
LOGFILE="/var/log/install_setup.log"
TZ="Asia/Jakarta"
WORKDIR="/root/install_setup"
URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"
BLOCKED_USER="diah082"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOGFILE"; }
fail(){ log "ERROR: $*"; exit 1; }

is_blocked_url() {
  local url="${1:-}"
  local lower
  lower="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *"github.com/$BLOCKED_USER"*) return 0 ;;
    *"raw.githubusercontent.com/$BLOCKED_USER"*) return 0 ;;
    *"gist.github.com/$BLOCKED_USER"*) return 0 ;;
    *"api.github.com/users/$BLOCKED_USER"*) return 0 ;;
    *"github.com:$BLOCKED_USER"*) return 0 ;;
    *) return 1 ;;
  esac
}

guard_url() {
  local url="${1:-}"
  if is_blocked_url "$url"; then
    fail "URL diblokir oleh policy lokal: $url"
  fi
}

download() {
  local url="$1"
  local out="$2"
  guard_url "$url"
  curl -fsSL "$url" -o "$out" || fail "download $url"
  chmod +x "$out"
}

log "RUN START"

apt-get update -y >/dev/null 2>&1 || true
apt-get install -y curl wget git chrony >/dev/null 2>&1 || true

timedatectl set-timezone "$TZ" >/dev/null 2>&1 || true
systemctl restart chrony >/dev/null 2>&1 || true

mkdir -p "$WORKDIR"

download "$URL_KUNCI" "$WORKDIR/kunci.sh"
bash "$WORKDIR/kunci.sh" || fail kunci

download "$URL_UBAH" "$WORKDIR/ubah.sh"
bash "$WORKDIR/ubah.sh" || fail ubah

download "$URL_FIXP" "$WORKDIR/fix.sh"
bash "$WORKDIR/fix.sh" || fail fix

log "RUN DONE"
sleep 2
EOF

  chmod +x "$WORKDIR/runner.sh"

  # Pasang wrapper sistem SEBELUM menjalankan runner
  setup_block_wrappers

  # Verifikasi blokir setelah wrapper dipasang
  if ! verify_blocking; then
    fail "Verifikasi blokir GAGAL. Pastikan wrapper terpasang dengan benar."
  fi

  screen -dmS "$SESSION_NAME" bash "$WORKDIR/runner.sh"

  wait_finish

  # Verifikasi ulang setelah instalasi selesai (opsional)
  log "Instalasi selesai, verifikasi blokir lagi..."
  verify_blocking || log "PERINGATAN: Verifikasi blokir setelah instalasi gagal, periksa manual."
}

main "$@"