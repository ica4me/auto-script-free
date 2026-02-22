#!/usr/bin/env bash
# =====================================================
# FINISH INSTALL — PRODUCTION SAFE FINAL
# Debian 9-13 / Ubuntu 16.04+
# =====================================================
set -Eeuo pipefail

SESSION_NAME="finish_install"
WORKDIR="/root/finish_install"
LOGFILE="/var/log/finish_install.log"
STATUS_FILE="$WORKDIR/status"
RUNNER_FILE="$WORKDIR/runner.sh"
RUN_ID="$(date +%Y%m%d-%H%M%S)"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"
URL_RESET="https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh"

# =====================================================
# BASIC
# =====================================================
require_root() {
  [ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
}

have(){ command -v "$1" >/dev/null 2>&1; }

apt_install(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null 2>&1 || true
  apt-get -yq install "$@" >/dev/null 2>&1
}

ensure_screen(){
  have screen || apt_install screen
}

# =====================================================
# CREATE RUNNER
# =====================================================
make_runner(){

mkdir -p "$WORKDIR"

cat > "$RUNNER_FILE" <<'RUNNER'
#!/usr/bin/env bash
set -Eeuo pipefail

LOGFILE="/var/log/finish_install.log"
WORKDIR="/root/finish_install"
STATUS_FILE="$WORKDIR/status"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"
URL_RESET="https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh"

RUN_ID="${RUN_ID:-unknown}"

log(){ echo "RUN_ID=$RUN_ID $1 $(date -Is)"; }

fail(){
  echo FAIL > "$STATUS_FILE"
  log "FAIL"
  exit 1
}

success(){
  echo DONE > "$STATUS_FILE"
  log "DONE"
}

trap fail ERR

# =====================================================
# DETECT ACTIVE SSH SESSION
# =====================================================
current_ssh_ip(){
  echo "${SSH_CLIENT:-}" | awk '{print $1}'
}

ssh_session_active(){
  local ip
  ip=$(current_ssh_ip)
  [ -z "$ip" ] && return 1

  ss -tnp 2>/dev/null | grep -q "$ip:.*sshd" && return 0
  who | grep -q "$ip" && return 0
  return 1
}

safe_restart_ssh(){

  if ssh_session_active; then
    echo "[SAFE] Active SSH detected — skip restart"
    return 0
  fi

  echo "[SAFE] Restarting SSH service"
  systemctl reload ssh 2>/dev/null || true
  systemctl reload sshd 2>/dev/null || true
  systemctl restart ssh 2>/dev/null || true
  systemctl restart sshd 2>/dev/null || true
  service ssh restart 2>/dev/null || true
  service sshd restart 2>/dev/null || true
}

# =====================================================
# ENSURE PACKAGES
# =====================================================
apt-get -yq update >/dev/null 2>&1 || true
apt-get -yq install wget curl e2fsprogs iproute2 >/dev/null 2>&1 || true

# =====================================================
# UNIVERSAL UNLOCK
# =====================================================
unlock_all(){

  chattr -R -i -a -u -e /etc/ssh 2>/dev/null || true

  FILES=(
    /etc/ssh/sshd_config
    /etc/ssh/sshd_config.d/01-permitrootlogin.conf
    /etc/ssh/sshd_config.d/by_najm.conf
    /root/.profile
    /root/.bashrc
    /etc/passwd
    /etc/shadow
    /etc/group
    /etc/gshadow
    /etc/sudoers
  )

  for f in "${FILES[@]}"; do
    [ -e "$f" ] || continue
    chattr -i -a -u -e "$f" 2>/dev/null || true
    chmod u+rw "$f" 2>/dev/null || true
  done
}

# =====================================================
# SAFE DOWNLOAD + EXEC
# =====================================================
run_script(){

  local url="$1"
  local file="$2"

  cd "$WORKDIR"
  rm -f "$file"

  wget -q "$url" -O "$file" || fail
  chmod +x "$file"

  unlock_all
  bash "$file"
}

# =====================================================
# MAIN EXECUTION
# =====================================================
exec >>"$LOGFILE" 2>&1
mkdir -p "$WORKDIR"
echo RUNNING > "$STATUS_FILE"

log START

unlock_all
run_script "$URL_KUNCI" kunci-ssh.sh

unlock_all
run_script "$URL_UBAH" ubah-ssh.sh
safe_restart_ssh

unlock_all
run_script "$URL_FIXP" fix-profile.sh

unlock_all
yes n | run_script "$URL_RESET" reset-user.sh
safe_restart_ssh

sync
success
RUNNER

chmod 700 "$RUNNER_FILE"
}

# =====================================================
# START SCREEN
# =====================================================
start_screen(){
  screen -S "$SESSION_NAME" -X quit >/dev/null 2>&1 || true
  screen -dmS "$SESSION_NAME" bash -lc "RUN_ID=$RUN_ID bash $RUNNER_FILE"
}

# =====================================================
# WAIT RESULT
# =====================================================
wait_result(){

  echo -n "Sedang Proses Finish Install... "

  TIMEOUT=900
  ELAPSED=0

  while true; do

    if [ -f "$STATUS_FILE" ]; then
      case "$(cat "$STATUS_FILE")" in
        DONE) echo "✅ SUKSES"; return 0 ;;
        FAIL) echo "❌ GAGAL"; tail -n 60 "$LOGFILE"; return 1 ;;
      esac
    fi

    if ! screen -list | grep -q "$SESSION_NAME"; then
        sleep 1
        if [ ! -f "$STATUS_FILE" ]; then
          echo "❌ GAGAL (runner crash)"
          tail -n 60 "$LOGFILE"
          return 1
        fi
    fi

    sleep 1
    ((ELAPSED++))

    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
      echo "❌ TIMEOUT"
      return 1
    fi
  done
}

# =====================================================
# MAIN
# =====================================================
main(){
  require_root
  ensure_screen
  make_runner
  start_screen
  wait_result
}

main "$@"