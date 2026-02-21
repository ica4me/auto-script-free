#!/usr/bin/env bash
# INSTALLER PRODUCTION STABLE
# Debian 9–13 / Ubuntu 16.04–24+

set -Eeo pipefail

SESSION_NAME="install_setup"
WORKDIR="/root/install_setup"
LOGFILE="/var/log/install_setup.log"
TZ="Asia/Jakarta"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

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
# DOWNLOAD DENGAN RETRY
########################################

download() {
  local url="$1"
  local out="$2"

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

log(){ echo "[$(date '+%F %T')] $*" >> "$LOGFILE"; }
fail(){ log "ERROR: $*"; exit 1; }
download(){ curl -fsSL "$1" -o "$2" || fail "download $1"; chmod +x "$2"; }

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

  screen -dmS "$SESSION_NAME" bash "$WORKDIR/runner.sh"

  wait_finish
}

main "$@"