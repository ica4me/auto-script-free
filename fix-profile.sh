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
echo "   FIX PROFILE: MODE DESTRUCTOR (TANPA LOCK PERMANEN)"
echo "========================================================"

# 1. BUKA ATRIBUT KUNCI (FORCE UNLOCK) — jika ada
echo "[+] Membuka atribut pengunci file (jika ada)..."
chattr -i -a -u -e "$TARGET_FILE" >/dev/null 2>&1 || true
chattr -i -a -u -e "$BASHRC_FILE" >/dev/null 2>&1 || true

# Cek status kunci
if [ -e "$TARGET_FILE" ]; then
    STATUS=$(lsattr "$TARGET_FILE" 2>/dev/null)
    echo "    Status Atribut: $STATUS"
else
    echo "    Status Atribut: (file belum ada)"
fi

# 2. HAPUS FILE LAMA (METODE PENGHANCURAN)
echo "[+] Menghapus file lama..."

# Langkah A: Kosongkan isi file (Truncate) - Efektif jika rm diblokir
truncate -s 0 "$TARGET_FILE" 2>/dev/null || true

# Langkah B: Hapus file
rm -f "$TARGET_FILE" 2>/dev/null || true

# Langkah C: Cek apakah file masih ada
if [ -f "$TARGET_FILE" ]; then
    echo "    ⚠️ File masih ada. Mencoba menimpa paksa..."
else
    echo "    ✅ File lama berhasil dihapus."
fi

# 3. DOWNLOAD FILE BARU
echo "[+] Mengunduh profile bersih..."
wget -q -O "$TARGET_FILE" "$DOWNLOAD_URL" || true

# Cek hasil download
if [ ! -s "$TARGET_FILE" ]; then
    echo "    ⚠️ Download gagal/kosong. Membuat profile default darurat..."
    cat > "$TARGET_FILE" <<'EOF'
# ~/.profile: executed by Bourne-compatible login shells.
if [ "$BASH" ]; then
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
chmod 644 "$TARGET_FILE" 2>/dev/null || true

# 4. TIDAK MENGUNCI FILE (SESUAI PERMINTAAN)
echo "[+] Melewati langkah penguncian (+i). File dibiarkan bisa diedit."

# 5. MEMBUAT ALAT EDIT (edit-profile) — buka kunci dulu kalau terkunci, lalu edit, TANPA mengunci lagi
echo "[+] Membuat alat edit: $LOCK_SCRIPT"
rm -f "$LOCK_SCRIPT" 2>/dev/null || true

cat > "$LOCK_SCRIPT" <<EOF
#!/bin/bash
TARGET="$TARGET_FILE"

echo "==================================================="
echo "   PROFILE EDITOR"
echo "   Jika file terkunci (immutable), akan dibuka dulu."
echo "==================================================="
read -s -p "Masukkan Password Admin (najm123): " MYPASS
echo ""

if [ "\$MYPASS" == "najm123" ]; then
    # Cek apakah immutable aktif
    if lsattr "\$TARGET" 2>/dev/null | grep -q "i"; then
        echo "🔓 File terdeteksi terkunci (immutable). Membuka kunci sementara..."
        chattr -i -a -u -e "\$TARGET" >/dev/null 2>&1 || true
    else
        echo "✅ File tidak terkunci. Langsung edit."
    fi

    echo "📝 Membuka NANO..."
    nano "\$TARGET"

    echo "✅ Selesai. File TIDAK dikunci kembali (sesuai permintaan)."
else
    echo "❌ PASSWORD SALAH! Akses ditolak."
    exit 1
fi
EOF

chmod +x "$LOCK_SCRIPT"