#!/usr/bin/env bash
set -euo pipefail

TARGET="/root/.ssh/authorized_keys"
# Password 'xccvme' yang di-encode menggunakan base64
SECRET_B64="eGNjdm1l"

if [[ "$EUID" -ne 0 ]]; then
  echo "Script ini harus dijalankan sebagai root." >&2
  exit 1
fi

# Meminta input password dari user tanpa menampilkannya di layar
echo -n "Masukkan password untuk mengubah status authorized_keys: "
read -s input_pass
echo

# Decode password dari base64
decoded_pass=$(echo "$SECRET_B64" | base64 --decode)

# Validasi password
if [[ "$input_pass" != "$decoded_pass" ]]; then
  echo "[!] Password salah! Akses ditolak." >&2
  exit 1
fi

echo -e "\n[+] Password Benar. Pilih aksi:"
echo "1) KUNCI: Buat dummy dan cegah modifikasi"
echo "2) BUKA KUNCI: Hapus dummy agar bisa diedit normal"
read -p "Masukkan pilihan (1/2): " choice

if [[ "$choice" == "1" ]]; then
  echo "[*] Membersihkan file lama..."
  chattr -i -a "$TARGET" 2>/dev/null || true
  rm -rf "$TARGET"
  
  echo "[*] Membuat dummy..."
  # Trik 1: Membuat FILE dummy sesuai permintaan Anda
  touch "$TARGET"
  
  # Trik 2 (Opsional tapi disarankan): 
  # Jika script lain masih tembus, ubah 'touch' di atas menjadi 'mkdir'
  # mkdir "$TARGET"

  # Menghapus semua hak akses (000) agar user root pun harus mengubah permission dulu
  chmod 000 "$TARGET"
  chown root:root "$TARGET"
  
  # Mengunci file dengan atribut immutable
  chattr +i "$TARGET"
  
  echo "[+] SUKSES: $TARGET telah dikunci rapat!"

elif [[ "$choice" == "2" ]]; then
  echo "[*] Membuka kunci dan menghapus dummy..."
  chattr -i -a "$TARGET" 2>/dev/null || true
  rm -rf "$TARGET"
  
  echo "[+] SUKSES: $TARGET sekarang bebas diedit/dibuat ulang."
else
  echo "[!] Pilihan tidak valid."
fi