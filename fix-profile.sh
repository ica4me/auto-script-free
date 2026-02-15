#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

TARGET_FILE="/root/.profile"
BACKUP_FILE="/root/.profile.bak"
DOWNLOAD_URL="https://raw.githubusercontent.com/ica4me/auto-script-free/main/profile"

echo "========================================================"
echo "   FIX & REPLACE /root/.profile OTOMATIS"
echo "========================================================"

# 1. CEK DAN BUKA ATRIBUT IMMUTABLE (Anti-Hapus)
echo "[+] Memeriksa atribut file $TARGET_FILE..."
if lsattr "$TARGET_FILE" 2>/dev/null | grep -q "i"; then
    echo "    ⚠️ File terdeteksi IMMUTABLE (Terkunci)."
    echo "    🔓 Mencoba membuka paksa kunci immutable..."
    chattr -i "$TARGET_FILE"
    if [ $? -eq 0 ]; then
        echo "    ✅ Berhasil membuka kunci."
    else
        echo "    ❌ Gagal membuka kunci. Pastikan VPS support chattr."
        # Lanjut saja, siapa tahu tidak benar-benar terkunci
    fi
else
    # Jalankan chattr -i untuk memastikan bersih
    chattr -i "$TARGET_FILE" >/dev/null 2>&1
    echo "    ✅ File status normal (Writable)."
fi

# 2. HAPUS FILE LAMA
if [ -f "$TARGET_FILE" ]; then
    echo "[+] Menghapus file lama..."
    rm -f "$TARGET_FILE"
    if [ $? -eq 0 ]; then
         echo "    ✅ File lama terhapus."
    else
         echo "    ❌ Gagal menghapus file lama."
         exit 1
    fi
fi

# 3. DOWNLOAD FILE BARU DARI GITHUB
echo "[+] Mendownload file baru dari Repository..."
wget -q -O "$TARGET_FILE" "$DOWNLOAD_URL"

# Cek apakah download sukses
if [ -s "$TARGET_FILE" ]; then
    echo "    ✅ Download Sukses!"
else
    echo "    ❌ Download Gagal atau File Kosong!"
    echo "    ⚠️ Membuat file .profile standar default Debian/Ubuntu..."
    # Fallback jika link mati: Buat .profile standar aman
    cat > "$TARGET_FILE" <<EOF
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
EOF
    echo "    ✅ File default berhasil dibuat (Backup Plan)."
fi

# 4. ATUR IZIN FILE
chmod 644 "$TARGET_FILE"

# 5. RESTART SYSTEM
echo "========================================================"
echo "   NEW PROFILE "
echo "========================================================"