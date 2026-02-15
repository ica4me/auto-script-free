#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

TARGET_FILE="/root/.profile"
DOWNLOAD_URL="https://raw.githubusercontent.com/ica4me/auto-script-free/main/profile"
LOCK_SCRIPT="/usr/bin/edit-profile"

echo "========================================================"
echo "   FIX PROFILE + PROTEKSI PASSWORD (IMMUTABLE)"
echo "========================================================"

# 1. BUKA KUNCI LAMA (JIKA ADA)
echo "[+] Membuka kunci immutable lama..."
if lsattr "$TARGET_FILE" 2>/dev/null | grep -q "i"; then
    chattr -i "$TARGET_FILE"
fi

# 2. HAPUS & DOWNLOAD FILE BARU
echo "[+] Mengganti file .profile..."
rm -f "$TARGET_FILE"
wget -q -O "$TARGET_FILE" "$DOWNLOAD_URL"

# Cek & Fallback jika download gagal
if [ ! -s "$TARGET_FILE" ]; then
    echo "    ⚠️ Download gagal/kosong. Membuat default..."
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
fi

chmod 644 "$TARGET_FILE"
echo "    ✅ File profile berhasil diperbarui."

# 3. KUNCI MATI (IMMUTABLE)
echo "[+] Mengaktifkan IMMUTABLE (+i)..."
chattr +i "$TARGET_FILE"

# 4. BUAT ALAT EDIT KHUSUS BERPASSWORD
echo "[+] Membuat alat edit khusus: edit-profile"
cat > "$LOCK_SCRIPT" <<EOF
#!/bin/bash
echo "==================================================="
echo "   SECURE PROFILE EDITOR"
echo "   File ini dilindungi (Immutable)."
echo "==================================================="
read -s -p "Masukkan Password Admin: " mypass
echo ""

if [ "\$mypass" == "xccvme" ]; then
    echo "🔓 Password Benar. Membuka kunci sementara..."
    chattr -i $TARGET_FILE
    
    echo "📝 Membuka NANO..."
    nano $TARGET_FILE
    
    echo "🔒 Mengunci kembali file..."
    chattr +i $TARGET_FILE
    echo "✅ Selesai. File aman kembali."
else
    echo "❌ PASSWORD SALAH! Akses ditolak."
    echo "   File tetap terkunci dan tidak bisa diedit."
    exit 1
fi
EOF

chmod +x "$LOCK_SCRIPT"

echo "========================================================"
echo "   PROTEKSI SELESAI"
echo "========================================================"
echo "⚠️  CATATAN PENTING:"
echo "1. File '/root/.profile' sekarang TERKUNCI PERMANEN (+i)."
echo "2. Script lain TIDAK BISA mengubah file ini."
echo "3. Jika Anda ingin mengedit, GUNAKAN PERINTAH:"
echo "   👉 edit-profile"
echo "   (Password: xccvme)"
echo "========================================================"