#!/usr/bin/env bash
# finish-install.sh - Debian 9-13 / Ubuntu 16.04-25.10
set -Eeuo pipefail

SESSION_NAME="finish_install"
WORKDIR="/root/finish_install"
LOGFILE="/var/log/finish_install.log"

URL_RESET="https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

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

URL_RESET="https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

SELF_PATH="${SELF_PATH:-}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install_quiet() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null 2>&1 || true
  apt-get -yq install "$@" >/dev/null 2>&1
}

download_to() {
  local url="$1" out="$2"
  if have_cmd curl; then
    curl -fsSL "$url" -o "$out"
  elif have_cmd wget; then
    wget -qO "$out" "$url"
  else
    apt_install_quiet curl wget
    if have_cmd curl; then
      curl -fsSL "$url" -o "$out"
    else
      wget -qO "$out" "$url"
    fi
  fi
  sed -i 's/\r$//' "$out" || true
  chmod 700 "$out" || true
}

run_remote_script_best() {
  local name="$1" url="$2"
  local f="$WORKDIR/${name}.sh"

  download_to "$url" "$f"

  # Penting: jalankan dari WORKDIR supaya "rm nama_script.sh" di dalam script remote tidak error
  (
    cd "$WORKDIR"
    bash "$f"
  )

  # Bersihkan file (kalau sudah dihapus oleh script remote, tidak akan error)
  rm -f "$f" >/dev/null 2>&1 || true
}

cleanup_and_self_delete() {
  rm -rf "$WORKDIR" >/dev/null 2>&1 || true
  if [ -n "${SELF_PATH:-}" ] && [ -f "$SELF_PATH" ]; then
    rm -f "$SELF_PATH" >/dev/null 2>&1 || true
  fi
}

main() {
  exec >>"$LOGFILE" 2>&1
  echo "RUN START: $(date -Is)"

  apt_install_quiet ca-certificates wget curl coreutils util-linux grep sed gawk || true
  mkdir -p "$WORKDIR"

  run_remote_script_best "reset-user"  "$URL_RESET"
  run_remote_script_best "ubah-ssh"    "$URL_UBAH"
  run_remote_script_best "fix-profile" "$URL_FIXP"

  echo "RUN DONE: $(date -Is)"
  cleanup_and_self_delete
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

  # kirim SELF_PATH ke runner supaya bisa self-delete
  screen -dmS "$SESSION_NAME" bash -lc "SELF_PATH='$SELF_PATH' bash '$WORKDIR/runner.sh'"
}

wait_with_spinner_until_done() {
  local frames='-\|/'
  local i=0

  printf "Sedang Proses Finish Install... "

  while true; do
    # sukses
    if [ -f "$LOGFILE" ] && grep -q "RUN DONE:" "$LOGFILE" 2>/dev/null; then
      printf "\rSedang Proses Finish Install... ✅ Selesai.\n"
      return 0
    fi

    # error: sudah start, tapi screen session hilang sebelum DONE
    if [ -f "$LOGFILE" ] && grep -q "RUN START:" "$LOGFILE" 2>/dev/null; then
      if ! screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
        printf "\rSedang Proses Finish Install... ❌ Gagal.\n"
        echo "Detail error cek log: $LOGFILE"
        echo "Ringkas (50 baris terakhir):"
        tail -n 50 "$LOGFILE" 2>/dev/null || true
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
