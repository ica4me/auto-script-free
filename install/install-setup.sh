#!/usr/bin/env bash
# install-setup.sh - Debian 9-13 / Ubuntu 16.04-25.10
set -Eeuo pipefail

SESSION_NAME="install_setup"
WORKDIR="/root/install_setup"
LOGFILE="/var/log/install_setup.log"

TZ="Asia/Jakarta"
URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

SELF_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "❌ Harus dijalankan sebagai root. Contoh: sudo bash install-setup.sh"
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
  # Normalisasi CRLF -> LF (hindari parsing aneh)
  sed -i 's/\r$//' "$out" || true
  chmod 700 "$out" || true
}

make_runner() {
  mkdir -p "$WORKDIR"
  cat > "$WORKDIR/runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -Eeuo pipefail

TZ="Asia/Jakarta"
LOGFILE="/var/log/install_setup.log"
WORKDIR="/root/install_setup"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
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

  echo "---- [$name] download ----"
  download_to "$url" "$f"

  # “Paling sakti”: jalankan via bash eksplisit (bukan ./file)
  echo "---- [$name] exec (bash $f) ----"
  bash "$f"
}

cleanup_and_self_delete() {
  # cleanup workdir
  rm -rf "$WORKDIR" >/dev/null 2>&1 || true
  # hapus file induk (best-effort)
  if [ -n "${SELF_PATH:-}" ] && [ -f "$SELF_PATH" ]; then
    rm -f "$SELF_PATH" >/dev/null 2>&1 || true
  fi
}

main() {
  exec >>"$LOGFILE" 2>&1
  echo "===================================================="
  echo "RUN START: $(date -Is)"
  echo "===================================================="

  apt_install_quiet ca-certificates wget curl coreutils util-linux grep sed gawk || true

  # Chrony + timezone
  apt_install_quiet chrony
  if have_cmd timedatectl; then
    timedatectl set-timezone "$TZ" || true
  else
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime || true
    echo "$TZ" > /etc/timezone || true
  fi

  systemctl restart chrony >/dev/null 2>&1 || service chrony restart >/dev/null 2>&1 || true

  mkdir -p "$WORKDIR"

  # Jalankan 3 script remote
  run_remote_script_best "kunci-ssh" "$URL_KUNCI"
  run_remote_script_best "ubah-ssh"  "$URL_UBAH"
  run_remote_script_best "fix-profile" "$URL_FIXP"

  echo "===================================================="
  echo "RUN DONE: $(date -Is)"
  echo "LOGFILE: $LOGFILE"
  echo "===================================================="

  cleanup_and_self_delete
}

main "$@"
RUNNER
  chmod 700 "$WORKDIR/runner.sh"
}

start_in_screen_detached() {
  touch "$LOGFILE" || true
  chmod 600 "$LOGFILE" || true

  # Kalau session sudah ada, jangan duplikasi
  if screen -list 2>/dev/null | grep -q "[[:space:]]${SESSION_NAME}[[:space:]]"; then
    return 0
  fi

  # Start detached, kirim SELF_PATH ke runner agar bisa self-delete
  screen -dmS "$SESSION_NAME" bash -lc "SELF_PATH='$SELF_PATH' bash '$WORKDIR/runner.sh'"
}

wait_with_loading_until_done() {
  echo "Proses Install ##....: mulai"
  echo "Log: $LOGFILE"
  echo "===================================================="
  echo "Loading... (akan selesai otomatis bila runner DONE)"
  echo "===================================================="

  # Ikuti log sampai ketemu marker RUN DONE, lalu tail berhenti otomatis
  # (tail -n0: mulai dari baris baru)
  ( tail -n0 -F "$LOGFILE" 2>/dev/null & echo $! > "$WORKDIR/tail.pid" ) || true

  # Loop cek marker selesai
  while true; do
    if [ -f "$LOGFILE" ] && grep -q "RUN DONE:" "$LOGFILE" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  # Matikan tail
  if [ -f "$WORKDIR/tail.pid" ]; then
    kill "$(cat "$WORKDIR/tail.pid")" >/dev/null 2>&1 || true
    rm -f "$WORKDIR/tail.pid" >/dev/null 2>&1 || true
  fi

  echo "===================================================="
  echo "Proses Install ##....: selesai"
  echo "Terminal sudah bisa dipakai untuk perintah berikutnya."
  echo "===================================================="
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
  wait_with_loading_until_done
}

main "$@"