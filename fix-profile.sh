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
echo "   FIX PROFILE: MODE JEBOL PAKSA (FORCE UNLOCK)"
echo "========================================================"

# 1. DIAGNOSA & JEBOL KUNCI
echo "[+] Memeriksa atribut file saat ini..."
lsattr "$TARGET_FILE"

echo "[+] MENJEBOL SEMUA KUNCI (-i dan -a)..."
# Hapus immutable dan append-only sekaligus
chattr -i -a "$TARGET_FILE" >/dev/null 2>&1
# Coba lagi dengan sudo (jaga-jaga)
sudo chattr -i -a "$TARGET_FILE" >/dev/null 2>&1

# Verifikasi apakah kunci terbuka
if lsattr "$TARGET_FILE" | grep -q "[ia]"; then
    echo "    ⚠️ PERINGATAN: Atribut masih terdeteksi! Mencoba metode kasar..."
fi

# 2. HAPUS FILE LAMA (METODE PENGHANCURAN)
echo "[+] Menghapus file lama..."

# Langkah A: Kosongkan isi file (Truncate) - Seringkali berhasil walau rm gagal
echo -n > "$TARGET_FILE"

# Langkah B: Hapus file
rm -f "$TARGET_FILE"

# Cek apakah file masih ada (Bandell!!)
if [ -f "$TARGET_FILE" ]; then
    echo "    ❌ GAGAL HAPUS! File ini sangat keras kepala."
    echo "    ⚠️ Mencoba menimpa paksa..."
    # Langkah C: Timpa paksa dengan download baru
    wget -q -O "$TARGET_FILE" "$DOWNLOAD_URL"
else
    echo "    ✅ File lama BERHASIL dimusnahkan."
    # Download file baru
    wget -q -O "$TARGET_FILE" "$DOWNLOAD_URL"
fi

# 3. VERIFIKASI ISI FILE
# Cek apakah file masih mengandung script jahat "NEWBIE STORE"
if grep -q "NEWBIE STORE" "$TARGET_FILE"; then
    echo "    ❌ GAWAT: File masih berisi script jahat! Sistem file Anda mungkin Read-Only."
    exit 1
else
    echo "    ✅ File profile BERHASIL diperbarui dan BERSIH."
fi

chmod 644 "$TARGET_FILE"

# 4. KUNCI MATI (IMMUTABLE)
echo "[+] Mengaktifkan PROTEKSI IMMUTABLE (+i)..."
chattr +i "$TARGET_FILE"

# 5. BUAT ALAT EDIT KHUSUS BERPASSWORD
echo "[+] Membuat alat edit khusus: edit-profile"
rm -f "$LOCK_SCRIPT" # Hapus script edit lama jika ada
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
    chattr -i -a $TARGET_FILE
    
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
echo "2. Script jahat sebelumnya SUDAH DIHAPUS."
echo "3. Jika Anda ingin mengedit, GUNAKAN PERINTAH:"
echo "   👉 edit-profile"
echo "   (Password: xccvme)"
echo "========================================================"