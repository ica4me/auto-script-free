#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

TARGET_FILE="/root/.profile"
BASHRC_FILE="/root/.bashrc"
DOWNLOAD_URL="https://raw.githubusercontent.com/ica4me/auto-script-free/main/profile"
LOCK_SCRIPT="/usr/bin/edit-profile"

echo "========================================================"
echo "   FIX PROFILE: MODE DESTRUCTOR (SUPER AGRESID)"
echo "========================================================"

# 1. JEBOL SEMUA ATRIBUT KUNCI (FORCE UNLOCK)
echo "[+] Menjebol semua atribut pengunci file..."
# -i: Immutable
# -a: Append Only
# -u: Undeletable
# -e: Extent format
chattr -i -a -u -e "$TARGET_FILE" >/dev/null 2>&1
chattr -i -a -u -e "$BASHRC_FILE" >/dev/null 2>&1

# Cek status kunci
STATUS=$(lsattr "$TARGET_FILE" 2>/dev/null)
echo "    Status Atribut: $STATUS"

# 2. HAPUS FILE LAMA (METODE PENGHANCURAN)
echo "[+] Menghapus file lama..."

# Langkah A: Kosongkan isi file (Truncate) - Efektif jika rm diblokir
truncate -s 0 "$TARGET_FILE" 2>/dev/null

# Langkah B: Hapus file
rm -f "$TARGET_FILE"

# Langkah C: Cek apakah file masih membandel
if [ -f "$TARGET_FILE" ]; then
    echo "    ⚠️ File masih ada. Mencoba menimpa paksa..."
else
    echo "    ✅ File lama berhasil dimusnahkan."
fi

# 3. DOWNLOAD FILE BARU
echo "[+] Mengunduh profile bersih..."
wget -q -O "$TARGET_FILE" "$DOWNLOAD_URL"

# Cek hasil download
if [ ! -s "$TARGET_FILE" ]; then
    echo "    ⚠️ Download gagal/kosong. Membuat profile default darurat..."
    cat > "$TARGET_FILE" <<EOF
# ~/.profile: executed by Bourne-compatible login shells.
if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
echo "Welcome to Server (Clean Profile)"
EOF
fi

# Pastikan izin file benar
chmod 644 "$TARGET_FILE"

# 4. KUNCI MATI (SUPER LOCK)
echo "[+] Mengaktifkan SUPER LOCK (+i)..."
chattr +i "$TARGET_FILE"

# Verifikasi kunci
if lsattr "$TARGET_FILE" | grep -q "i"; then
    echo "    🔒 SUKSES: File BERHASIL dikunci Mati."
else
    echo "    ⚠️ PERINGATAN: Gagal mengunci file."
fi

# 5. MEMBUAT ALAT EDIT KHUSUS (edit-profile)
echo "[+] Membuat alat edit aman: $LOCK_SCRIPT"
rm -f "$LOCK_SCRIPT" # Hapus versi lama
cat > "$LOCK_SCRIPT" <<EOF
#!/bin/bash
TARGET="$TARGET_FILE"

echo "==================================================="
echo "   SECURE PROFILE EDITOR"
echo "   File ini dilindungi (Immutable)."
echo "==================================================="
read -s -p "Masukkan Password Admin (xccvme): " MYPASS
echo ""

if [ "\$MYPASS" == "xccvme" ]; then
    echo "🔓 Password Benar. Membuka kunci sementara..."
    chattr -i -a -u -e \$TARGET
    
    echo "📝 Membuka NANO..."
    nano \$TARGET
    
    echo "🔒 Mengunci kembali file..."
    chattr +i \$TARGET
    echo "✅ Selesai. File aman kembali."
else
    echo "❌ PASSWORD SALAH! Akses ditolak."
    echo "   File tetap terkunci dan tidak bisa diedit."
    exit 1
fi
EOF

# Beri izin eksekusi pada alat edit
chmod +x "$LOCK_SCRIPT"

echo "========================================================"
echo "   SELESAI. PROFILE TELAH DIPERBAIKI & DIKUNCI."
echo "========================================================"
echo "⚠️  CATATAN:"
echo "1. File '/root/.profile' sekarang TERKUNCI PERMANEN (+i)."
echo "2. Untuk mengeditnya, WAJIB gunakan perintah:"
echo "   👉 edit-profile"
echo "   (Password: xccvme)"
echo "========================================================"