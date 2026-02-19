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

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install_quiet() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null 2>&1 || true
  apt-get -yq install "$@" >/dev/null 2>&1
}

need_cmds() {
  apt_install_quiet ca-certificates wget curl coreutils util-linux grep sed gawk >/dev/null 2>&1 || true
}

# Jalankan dengan metode yang SAMA PERSIS seperti manual user:
# wget -q URL; chmod +x file; ./file
run_like_manual() {
  local url="$1"
  local file="$2"

  cd "$WORKDIR"

  # hapus sisa file jika ada (silent)
  rm -f "$file" >/dev/null 2>&1 || true

  # download dengan nama default (agar self-delete rm file.sh di script remote cocok)
  wget -q "$url"

  # normalisasi CRLF (aman)
  sed -i 's/\r$//' "$file" >/dev/null 2>&1 || true

  chmod +x "$file"

  # Jalankan pakai ./ (sama seperti Anda)
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
  echo "RUN START: $(date -Is)"

  need_cmds
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  # URUTAN sesuai permintaan Anda:
  run_like_manual "$URL_KUNCI" "kunci-ssh.sh"
  run_like_manual "$URL_UBAH"  "ubah-ssh.sh"
  run_like_manual "$URL_FIXP"  "fix-profile.sh"
  run_like_manual "$URL_RESET" "reset-user.sh"

  echo "RUN DONE: $(date -Is)"
  cleanup_all
}

main "$@"
RUNNER
  chmod 700 "$WORKDIR/runner.sh"
}

start_in_screen_detached() {
  mkdir -p "$WORKDIR"
  touch "$LOGFILE" || true
  chmod 600 "$LOGFILE" || true

  # jika session sudah ada, jangan dobel
  if screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
    return 0
  fi

  screen -dmS "$SESSION_NAME" bash -lc "SELF_PATH='$SELF_PATH' bash '$WORKDIR/runner.sh'"
}

wait_with_spinner_until_done() {
  local frames='-\|/'
  local i=0
  printf "Sedang Proses Finish Install... "

  while true; do
    if [ -f "$LOGFILE" ] && grep -q "RUN DONE:" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Finish Install... ✅ Selesai.\n"
      return 0
    fi

    if [ -f "$LOGFILE" ] && grep -q "RUN START:" "$LOGFILE" 2>/dev/null; then
      if ! screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
        printf "\rSedang Proses Finish Install... ❌ Gagal.\n"
        echo "Detail error cek log: $LOGFILE"
        echo "Ringkas (80 baris terakhir):"
        tail -n 80 "$LOGFILE" 2>/dev/null || true
        return 1
      fi
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
