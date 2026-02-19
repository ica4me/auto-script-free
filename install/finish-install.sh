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

pick_mux() {
  if have_cmd tmux; then echo "tmux"; return; fi
  if have_cmd screen; then echo "screen"; return; fi

  apt_install_quiet tmux || true
  if have_cmd tmux; then echo "tmux"; return; fi

  apt_install_quiet screen || true
  if have_cmd screen; then echo "screen"; return; fi

  echo "none"
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
  # Normalisasi CRLF -> LF supaya parsing bash stabil
  sed -i 's/\r$//' "$out" || true
  chmod 700 "$out" || true
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

# Dikirim oleh script induk via environment saat spawn
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

  # “Paling sakti”: jalankan via bash eksplisit, bukan ./file
  echo "---- [$name] exec (bash $f) ----"
  bash "$f"
}

main() {
  exec >>"$LOGFILE" 2>&1
  echo "===================================================="
  echo "RUN START: $(date -Is)"
  echo "===================================================="

  # Dependensi minimal
  apt_install_quiet ca-certificates wget curl coreutils util-linux grep sed gawk || true
  mkdir -p "$WORKDIR"

  # Urutan sesuai permintaan
  run_remote_script_best "reset-user"  "$URL_RESET"
  run_remote_script_best "ubah-ssh"    "$URL_UBAH"
  run_remote_script_best "fix-profile" "$URL_FIXP"

  echo "===================================================="
  echo "RUN DONE: $(date -Is)"
  echo "LOGFILE: $LOGFILE"
  echo "===================================================="

  # Hapus diri sendiri (best-effort). Kalau SELF_PATH kosong, skip aman.
  if [ -n "${SELF_PATH:-}" ] && [ -f "$SELF_PATH" ]; then
    rm -f "$SELF_PATH" || true
  fi
}

main "$@"
RUNNER
  chmod 700 "$WORKDIR/runner.sh"
}

start_detached() {
  local mux="$1"

  touch "$LOGFILE" || true
  chmod 600 "$LOGFILE" || true

  if [ "$mux" = "tmux" ]; then
    if tmux has-session -t "$SESSION_NAME" >/dev/null 2>&1; then
      return 0
    fi
    # Pass SELF_PATH ke runner agar bisa self-delete
    tmux new-session -d -s "$SESSION_NAME" "SELF_PATH='$SELF_PATH' bash '$WORKDIR/runner.sh'"
    return 0
  fi

  if [ "$mux" = "screen" ]; then
    if screen -list 2>/dev/null | grep -q "[[:space:]]$SESSION_NAME"; then
      return 0
    fi
    screen -dmS "$SESSION_NAME" bash -lc "SELF_PATH='$SELF_PATH' bash '$WORKDIR/runner.sh'"
    return 0
  fi

  return 1
}

print_minimal_status_and_exit() {
  echo -n "Proses Install ##....: "
  echo "jalan di background"
  echo "Log: $LOGFILE"
  echo "Monitor: tail -f $LOGFILE"
  echo "Attach tmux:  tmux attach -t $SESSION_NAME"
  echo "Attach screen: screen -r $SESSION_NAME"
}

main() {
  require_root

  if ! have_cmd apt-get; then
    echo "❌ Sistem ini tidak menggunakan apt-get."
    exit 1
  fi

  make_runner

  local mux
  mux="$(pick_mux)"
  if [ "$mux" = "none" ]; then
    echo "❌ Gagal menyiapkan tmux/screen. Coba: apt-get install -y tmux"
    exit 1
  fi

  if ! start_detached "$mux"; then
    echo "❌ Gagal menjalankan session background."
    exit 1
  fi

  print_minimal_status_and_exit
}

main "$@"
