#!/usr/bin/env bash
# install.sh - Debian 9-13 / Ubuntu 16.04-25.10
set -Eeuo pipefail

SESSION_NAME="install_auto"
WORKDIR="/root/install_auto"
LOGFILE="/var/log/install_auto.log"

TZ="Asia/Jakarta"
URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "❌ Harus dijalankan sebagai root. Contoh: sudo bash install.sh"
    exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install_quiet() {
  # Minimal output, tetap robust
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update >/dev/null 2>&1 || true
  apt-get -yq install "$@" >/dev/null 2>&1
}

pick_mux() {
  if have_cmd tmux; then
    echo "tmux"
    return
  fi
  if have_cmd screen; then
    echo "screen"
    return
  fi

  # Install salah satu (prefer tmux)
  apt_install_quiet tmux || true
  if have_cmd tmux; then
    echo "tmux"
    return
  fi

  apt_install_quiet screen || true
  if have_cmd screen; then
    echo "screen"
    return
  fi

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
  # Normalisasi CRLF -> LF (kadang bikin parsing aneh)
  sed -i 's/\r$//' "$out" || true
  chmod 700 "$out" || true
}

make_runner() {
  mkdir -p "$WORKDIR"
  cat > "$WORKDIR/runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -Eeuo pipefail

TZ="Asia/Jakarta"
LOGFILE="/var/log/install_auto.log"
WORKDIR="/root/install_auto"

URL_KUNCI="https://raw.githubusercontent.com/ica4me/auto-script-free/main/kunci-ssh.sh"
URL_UBAH="https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh"
URL_FIXP="https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh"

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

  # Cara terbaik (menghindari masalah shebang rusak / permission / format):
  # jalankan via bash eksplisit, bukan ./file
  echo "---- [$name] exec (bash $f) ----"
  bash "$f"
}

main() {
  exec >>"$LOGFILE" 2>&1
  echo "===================================================="
  echo "RUN START: $(date -Is)"
  echo "===================================================="

  # Dependensi dasar
  apt_install_quiet ca-certificates wget curl coreutils util-linux grep sed gawk || true

  # Chrony + timezone
  apt_install_quiet chrony
  if have_cmd timedatectl; then
    timedatectl set-timezone "$TZ" || true
  else
    # Fallback (sangat lama / minimal image)
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
}

main "$@"
RUNNER
  chmod 700 "$WORKDIR/runner.sh"
}

start_detached() {
  local mux="$1"
  # Pastikan log bisa ditulis
  touch "$LOGFILE" || true
  chmod 600 "$LOGFILE" || true

  if [ "$mux" = "tmux" ]; then
    # Jika session sudah ada, jangan duplikasi
    if tmux has-session -t "$SESSION_NAME" >/dev/null 2>&1; then
      return 0
    fi
    tmux new-session -d -s "$SESSION_NAME" "bash '$WORKDIR/runner.sh'"
    return 0
  fi

  if [ "$mux" = "screen" ]; then
    # Cek session existing (best-effort)
    if screen -list 2>/dev/null | grep -q "[[:space:]]$SESSION_NAME"; then
      return 0
    fi
    screen -dmS "$SESSION_NAME" bash -lc "bash '$WORKDIR/runner.sh'"
    return 0
  fi

  return 1
}

print_minimal_status_and_exit() {
  # Minimal output sesuai permintaan
  echo -n "Proses Install ##....: "
  echo "jalan di background"
  echo "Log: $LOGFILE"
  echo "Monitor:"
  echo "  tail -f $LOGFILE"
  echo "Attach (tmux):"
  echo "  tmux attach -t $SESSION_NAME"
  echo "Attach (screen):"
  echo "  screen -r $SESSION_NAME"
}

main() {
  require_root

  # Pastikan apt tersedia
  if ! have_cmd apt-get; then
    echo "❌ Sistem ini tidak menggunakan apt-get."
    exit 1
  fi

  # Siapkan runner
  make_runner

  # Pastikan multiplexer ada
  local mux
  mux="$(pick_mux)"
  if [ "$mux" = "none" ]; then
    echo "❌ Gagal menyiapkan tmux/screen."
    echo "Cek koneksi repo apt atau install manual: apt-get install -y tmux"
    exit 1
  fi

  # Start detached
  if ! start_detached "$mux"; then
    echo "❌ Gagal menjalankan background session."
    exit 1
  fi

  print_minimal_status_and_exit
}

main "$@"
