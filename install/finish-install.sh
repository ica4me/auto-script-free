#!/usr/bin/env bash
# finish-install.sh - Debian 9-13 / Ubuntu 16.04-25.10 (Fixed & Improved)
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
  echo "RUN_ID=${RUN_ID} $1: $(date -Is)"
}

# Fungsi Universal untuk Membuka Semua Kunci Sebelum Mengedit
unlock_critical_files() {
  echo "[+] Membuka kunci (unlock) semua file target jika terkunci..."
  
  local files=(
    "/etc/ssh/sshd_config"
    "/etc/ssh/sshd_config.d/01-permitrootlogin.conf"
    "/etc/ssh/sshd_config.d/by_najm.conf"
    "/root/.profile"
    "/root/.bashrc"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/gshadow"
    "/etc/sudoers"
  )

  # Unlock direktori SSH
  chattr -R -i -a -u -e /etc/ssh >/dev/null 2>&1 || true

  # Membuka atribut (immutable) dan memberikan izin tulis standar
  for f in "${files[@]}"; do
    if [ -e "$f" ]; then
      chattr -i -a -u -e "$f" >/dev/null 2>&1 || true
      chmod 644 "$f" >/dev/null 2>&1 || true
    fi
  done
}

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

  # 1) Buka kunci lalu jalankan script kunci SSH
  unlock_critical_files
  run_like_manual "$URL_KUNCI" "kunci-ssh.sh"

  # 2) Buka kunci lagi lalu jalankan script ubah SSH
  unlock_critical_files
  run_like_manual "$URL_UBAH" "ubah-ssh.sh"

  # 3) Buka kunci lalu jalankan script perbaikan Profile
  unlock_critical_files
  run_like_manual "$URL_FIXP" "fix-profile.sh"

  # 4) Buka kunci lalu jalankan reset user
  unlock_critical_files
  run_like_manual "$URL_RESET" "reset-user.sh"

  # Memaksa sinkronisasi disk agar file log segera tersimpan (mencegah false-alarm gagal)
  sync
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

  if screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
    screen -S "$SESSION_NAME" -X quit >/dev/null 2>&1 || true
  fi

  screen -dmS "$SESSION_NAME" bash -lc "SELF_PATH='$SELF_PATH' RUN_ID='$RUN_ID' bash '$WORKDIR/runner.sh'"
}

wait_with_spinner_until_done() {
  local frames='-\|/'
  local i=0

  printf "Sedang Proses Finish Install... "

  while true; do
    if [ -f "$LOGFILE" ] && grep -q "RUN_ID=${RUN_ID} DONE:" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Finish Install... ✅ SUKSES.\n"
      return 0
    fi

    if [ -f "$LOGFILE" ] && grep -q "RUN_ID=${RUN_ID} FAIL:" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Finish Install... ❌ GAGAL.\n"
      echo "Detail error cek log: $LOGFILE"
      tail -n 50 "$LOGFILE" 2>/dev/null || true
      return 1
    fi

    # Jika session screen berhenti, beri waktu tunggu 5 detik agar log selesai ditulis
    if ! screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
      for _ in {1..10}; do
        sleep 0.5
        if grep -q "RUN_ID=${RUN_ID} DONE:" "$LOGFILE" 2>/dev/null; then
          printf "\rSedang Proses Finish Install... ✅ SUKSES.\n"
          return 0
        fi
        if grep -q "RUN_ID=${RUN_ID} FAIL:" "$LOGFILE" 2>/dev/null; then
          printf "\rSedang Proses Finish Install... ❌ GAGAL.\n"
          return 1
        fi
      done
      
      printf "\rSedang Proses Finish Install... ❌ GAGAL (session berhenti abnormal).\n"
      echo "Silakan cek log: $LOGFILE"
      tail -n 50 "$LOGFILE" 2>/dev/null || true
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