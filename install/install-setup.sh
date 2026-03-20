#!/usr/bin/env bash
# INSTALLER PRODUCTION STABLE
# Debian 9–13 / Ubuntu 16.04–24+
# Enhanced: System-wide blocking of GitHub user "diah082"

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
# SYSTEM-WIDE WRAPPER UNTUK CURL/WGET
########################################

setup_block_wrappers() {
  log "Memasang wrapper sistem untuk curl dan wget (blokir $BLOCKED_USER)"

  # Fungsi untuk membuat wrapper curl
  create_curl_wrapper() {
    local orig_curl
    if [ -x /usr/bin/curl ]; then
      orig_curl="/usr/bin/curl"
    elif [ -x /usr/local/bin/curl ]; then
      orig_curl="/usr/local/bin/curl"
    else
      log "curl tidak ditemukan, lewati pembuatan wrapper"
      return 0
    fi

    # Pindahkan binary asli
    if [ ! -f "${orig_curl}.orig" ]; then
      mv "$orig_curl" "${orig_curl}.orig" || return 1
    fi

    cat > "$orig_curl" <<'EOF'
#!/bin/bash
# Wrapper curl untuk memblokir akses ke username tertentu
ORIG_CURL="%s"
BLOCKED_USER="diah082"

is_blocked_url() {
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
        *)
            return 1 ;;
    esac
}

for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]]; then
        if is_blocked_url "$arg"; then
            echo "ERROR: Akses ke $arg diblokir (user $BLOCKED_USER)" >&2
            exit 1
        fi
    fi
done

exec "$ORIG_CURL" "$@"
EOF
    sed -i "s|%s|${orig_curl}.orig|g" "$orig_curl"
    chmod +x "$orig_curl"
    log "Wrapper curl dipasang di $orig_curl"
  }

  # Fungsi untuk membuat wrapper wget
  create_wget_wrapper() {
    local orig_wget
    if [ -x /usr/bin/wget ]; then
      orig_wget="/usr/bin/wget"
    elif [ -x /usr/local/bin/wget ]; then
      orig_wget="/usr/local/bin/wget"
    else
      log "wget tidak ditemukan, lewati pembuatan wrapper"
      return 0
    fi

    if [ ! -f "${orig_wget}.orig" ]; then
      mv "$orig_wget" "${orig_wget}.orig" || return 1
    fi

    cat > "$orig_wget" <<'EOF'
#!/bin/bash
# Wrapper wget untuk memblokir akses ke username tertentu
ORIG_WGET="%s"
BLOCKED_USER="diah082"

is_blocked_url() {
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
        *)
            return 1 ;;
    esac
}

for arg in "$@"; do
    if [[ "$arg" =~ ^https?:// ]]; then
        if is_blocked_url "$arg"; then
            echo "ERROR: Akses ke $arg diblokir (user $BLOCKED_USER)" >&2
            exit 1
        fi
    fi
done

exec "$ORIG_WGET" "$@"
EOF
    sed -i "s|%s|${orig_wget}.orig|g" "$orig_wget"
    chmod +x "$orig_wget"
    log "Wrapper wget dipasang di $orig_wget"
  }

  create_curl_wrapper || fail "Gagal memasang wrapper curl"
  create_wget_wrapper || fail "Gagal memasang wrapper wget"
}

########################################
# RUNNER
########################################

runner() {

  log "===== RUN START ====="

  apt_quiet ca-certificates curl wget
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
apt-get install -y curl wget chrony >/dev/null 2>&1 || true

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

  # Pasang wrapper sistem sebelum menjalankan runner
  setup_block_wrappers

  screen -dmS "$SESSION_NAME" bash "$WORKDIR/runner.sh"

  wait_finish
}

main "$@"