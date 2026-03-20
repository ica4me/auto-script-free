#!/usr/bin/env bash
set -euo pipefail

TARGET="/root/.ssh/authorized_keys"
# Password 'xccvme' yang di-encode menggunakan base64
SECRET_B64="eGNjdm1l"

if [[ "$EUID" -ne 0 ]]; then
  echo "Script ini harus dijalankan sebagai root." >&2
  exit 1
fi

# Fungsi untuk mengunci file secara diam-diam (Silent)
lock_file() {
  chattr -i -a "$TARGET" 2>/dev/null || true
  rm -rf "$TARGET"
  
  touch "$TARGET"
  chmod 000 "$TARGET"
  chown root:root "$TARGET"
  chattr +i "$TARGET"
}

# Cek apakah script dijalankan dengan argumen 'edit'
if [[ "${1:-}" == "edit" ]]; then
  # --- MODE INTERAKTIF (MANUAL NANO) ---
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
  # Pastikan file ada agar nano tidak error, lalu beri izin edit sementara
  touch "$TARGET" 2>/dev/null || true
  chmod 600 "$TARGET"

  # Membuka nano untuk user
  nano "$TARGET"

  # Setelah user keluar dari nano (save/exit), otomatis kunci kembali
  echo "[*] Mengunci kembali file authorized_keys..."
  lock_file
  echo "[+] File telah diamankan kembali."
  exit 0
fi

# --- MODE DEFAULT (EKSEKUSI LANGSUNG TANPA INTERAKSI) ---
# Jika dijalankan tanpa argumen 'edit', langsung gembok diam-diam
lock_file
echo "[+] $TARGET berhasil dikunci secara otomatis."