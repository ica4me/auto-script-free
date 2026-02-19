#!/usr/bin/env bash
# finish-install.sh - Debian 9-13 / Ubuntu 16.04-25.10
set -Eeuo pipefail

SESSION_NAME="finish_install"
WORKDIR="/root/finish_install"
LOGFILE="/var/log/finish_install.log"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"
URL_RESET="https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh"

SELF_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
RUN_ID="$(date +%Y%m%d-%H%M%S)"

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "❌ Harus dijalankan sebagai root. Contoh: sudo bash finish-install.sh"
    exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install_quiet() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null 2>&1 || true
  apt-get -yq install "$@" >/dev/null 2>&1
}

ensure_screen() {
  if have_cmd screen; then return 0; fi
  apt_install_quiet screen
  have_cmd screen
}

make_runner() {
  mkdir -p "$WORKDIR"
  cat > "$WORKDIR/runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -Eeuo pipefail

LOGFILE="/var/log/finish_install.log"
WORKDIR="/root/finish_install"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"
URL_RESET="https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh"

SELF_PATH="${SELF_PATH:-}"
RUN_ID="${RUN_ID:-unknown}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install_quiet() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null 2>&1 || true
  apt-get -yq install "$@" >/dev/null 2>&1
}

need_cmds() {
  apt_install_quiet ca-certificates wget curl coreutils util-linux grep sed gawk e2fsprogs >/dev/null 2>&1 || true
}

log_mark() {
  # marker pendek, mudah diparse
  echo "RUN_ID=${RUN_ID} $1: $(date -Is)"
}

unlock_ssh_blockers() {
  # Buka immutable/permission yang sering bikin script lain gagal
  local f="/etc/ssh/sshd_config.d/01-permitrootlogin.conf"
  local d="/etc/ssh/sshd_config.d"
  local sshd="/etc/ssh/sshd_config"

  # unlock dir & file (best-effort, tidak bikin exit)
  chattr -R -i -a -u -e /etc/ssh >/dev/null 2>&1 || true
  [ -d "$d" ] && chattr -i -a -u -e "$d" >/dev/null 2>&1 || true

  if [ -e "$f" ]; then
    chattr -i -a -u -e "$f" >/dev/null 2>&1 || true
    chmod 644 "$f" >/dev/null 2>&1 || true
  fi

  if [ -f "$sshd" ]; then
    chattr -i -a -u -e "$sshd" >/dev/null 2>&1 || true
    chmod 644 "$sshd" >/dev/null 2>&1 || true
  fi
}

# Jalankan persis seperti manual:
# wget -q URL; chmod +x file; ./file
run_like_manual() {
  local url="$1"
  local file="$2"

  cd "$WORKDIR"
  rm -f "$file" >/dev/null 2>&1 || true

  wget -q "$url"
  sed -i 's/\r$//' "$file" >/dev/null 2>&1 || true
  chmod +x "$file"

  "./$file"
}

cleanup_all() {
  rm -rf "$WORKDIR" >/dev/null 2>&1 || true
  if [ -n "${SELF_PATH:-}" ] && [ -f "$SELF_PATH" ]; then
    rm -f "$SELF_PATH" >/dev/null 2>&1 || true
  fi
}

main() {
  exec >>"$LOGFILE" 2>&1

  mkdir -p "$WORKDIR"
  need_cmds

  log_mark "START"

  # Pastikan state ssh tidak nyangkut dari run sebelumnya
  unlock_ssh_blockers

  # Urutan yang Anda minta:
  # 1) kunci-ssh
  run_like_manual "$URL_KUNCI" "kunci-ssh.sh"

  # Setelah kunci, kita unlock dulu supaya step berikutnya bisa ubah tanpa bentrok,
  # dan supaya Anda bisa rm/edit file permitrootlogin bila perlu.
  unlock_ssh_blockers

  # 2) ubah-ssh
  run_like_manual "$URL_UBAH" "ubah-ssh.sh"

  # 3) fix-profile
  run_like_manual "$URL_FIXP" "fix-profile.sh"

  # 4) reset-user (ini restart ssh; kalau ssh config invalid akan gagal)
  run_like_manual "$URL_RESET" "reset-user.sh"

  log_mark "DONE"
  cleanup_all
}

trap 'log_mark "FAIL"; exit 1' ERR
main "$@"
RUNNER
  chmod 700 "$WORKDIR/runner.sh"
}

start_in_screen_detached() {
  mkdir -p "$WORKDIR"
  touch "$LOGFILE" || true
  chmod 600 "$LOGFILE" || true

  # kalau session sudah ada, hentikan dulu agar tidak tabrakan run
  if screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
    # best-effort kill session
    screen -S "$SESSION_NAME" -X quit >/dev/null 2>&1 || true
  fi

  screen -dmS "$SESSION_NAME" bash -lc "SELF_PATH='$SELF_PATH' RUN_ID='$RUN_ID' bash '$WORKDIR/runner.sh'"
}

wait_with_spinner_until_done() {
  local frames='-\|/'
  local i=0

  printf "Sedang Proses Finish Install... "

  while true; do
    # sukses untuk RUN_ID ini
    if [ -f "$LOGFILE" ] && grep -q "RUN_ID=${RUN_ID} DONE:" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Finish Install... ✅ Selesai.\n"
      return 0
    fi

    # gagal untuk RUN_ID ini
    if [ -f "$LOGFILE" ] && grep -q "RUN_ID=${RUN_ID} FAIL:" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Finish Install... ❌ Gagal.\n"
      echo "Detail error cek log: $LOGFILE"
      echo "Ringkas (120 baris terakhir):"
      tail -n 120 "$LOGFILE" 2>/dev/null || true
      return 1
    fi

    # safety: kalau session hilang tapi tidak ada DONE/FAIL (misal crash keras)
    if ! screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
      # tunggu sedikit agar log sempat flush
      sleep 0.5
      if [ -f "$LOGFILE" ] && grep -q "RUN_ID=${RUN_ID} DONE:" "$LOGFILE" 2>/dev/null; then
        printf "\rSedang Proses Finish Install... ✅ Selesai.\n"
        return 0
      fi
      if [ -f "$LOGFILE" ] && grep -q "RUN_ID=${RUN_ID} FAIL:" "$LOGFILE" 2>/dev/null; then
        printf "\rSedang Proses Finish Install... ❌ Gagal.\n"
        echo "Detail error cek log: $LOGFILE"
        echo "Ringkas (120 baris terakhir):"
        tail -n 120 "$LOGFILE" 2>/dev/null || true
        return 1
      fi
      printf "\rSedang Proses Finish Install... ❌ Gagal (session berhenti).\n"
      echo "Detail error cek log: $LOGFILE"
      echo "Ringkas (120 baris terakhir):"
      tail -n 120 "$LOGFILE" 2>/dev/null || true
      return 1
    fi

    printf "\rSedang Proses Finish Install... %c" "${frames:i%4:1}"
    i=$((i+1))
    sleep 0.2
  done
}

main() {
  require_root
  if ! have_cmd apt-get; then
    echo "❌ Sistem ini tidak menggunakan apt-get."
    exit 1
  fi

  if ! ensure_screen; then
    echo "❌ Gagal install/menemukan screen."
    exit 1
  fi

  make_runner
  start_in_screen_detached
  wait_with_spinner_until_done
}

main "$@"
