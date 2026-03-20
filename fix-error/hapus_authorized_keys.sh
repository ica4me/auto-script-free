#!/usr/bin/env bash
set -euo pipefail

TARGET="/root/.ssh/authorized_keys"

if [[ "$EUID" -ne 0 ]]; then
  echo "Harus dijalankan sebagai root." >&2
  exit 1
fi

if [[ ! -e "$TARGET" ]]; then
  echo "File tidak ada: $TARGET"
  exit 0
fi

if [[ ! -f "$TARGET" ]]; then
  echo "Target bukan file biasa, batal: $TARGET" >&2
  exit 1
fi

echo "[*] Melepas immutable/appended flag bila ada..."
chattr -i -a "$TARGET" 2>/dev/null || true

echo "[*] Mengubah izin agar bisa dihapus..."
chmod 600 "$TARGET" 2>/dev/null || true

echo "[*] Menghapus file..."
rm -f -- "$TARGET"

if [[ -e "$TARGET" ]]; then
  echo "[!] Gagal menghapus: $TARGET" >&2
  exit 1
fi

echo "[+] Berhasil dihapus: $TARGET"