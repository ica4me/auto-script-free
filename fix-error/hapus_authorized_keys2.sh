#!/usr/bin/env bash
set -euo pipefail

TARGET="/root/.ssh/authorized_keys"
SECRET_B64="eGNjdm1l"

if [[ "$EUID" -ne 0 ]]; then
  echo "Script ini harus dijalankan sebagai root." >&2
  exit 1
fi

lock_file() {
  chattr -i -a "$TARGET" 2>/dev/null || true
  rm -rf "$TARGET"
  
  touch "$TARGET"
  chmod 000 "$TARGET"
  chown root:root "$TARGET"
  chattr +i "$TARGET"
}

if [[ "${1:-}" == "edit" ]]; then
  echo -n "Masukkan password untuk membuka nano: "
  read -s input_pass
  echo

  decoded_pass=$(echo "$SECRET_B64" | base64 --decode)

  if [[ "$input_pass" != "$decoded_pass" ]]; then
    echo "[!] Password salah! Akses ditolak." >&2
    exit 1
  fi

  echo "[*] Password Benar. Membuka gembok sementara..."
  chattr -i -a "$TARGET" 2>/dev/null || true
  touch "$TARGET" 2>/dev/null || true
  chmod 600 "$TARGET"
  nano "$TARGET"
  echo "[*] Mengunci kembali file authorized_keys..."
  lock_file
  echo "[+] File telah diamankan kembali."
  exit 0
fi

lock_file
echo "[+] $TARGET berhasil dikunci secara otomatis."