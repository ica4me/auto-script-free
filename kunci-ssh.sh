#!/bin/bash
set -e

# ==========================================
# KONFIGURASI TARGET & PASSWORD
# ==========================================
TARGET_FILE="/etc/ssh/sshd_config.d/01-permitrootlogin.conf"
UNLOCK_TOOL="/usr/bin/buka-blokir-ssh"
# Ganti password ini sesuai keinginan Anda
MY_PASSWORD="admin" 
# ==========================================

# Cek Root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Error: Script harus dijalankan sebagai root!"
  exit 1
fi

echo "====================================================="
echo "   MENGAMANKAN FILE CONFIG DARI OVERRIDE SISTEM"
echo "====================================================="

# 1. Buka kunci lama (jika pernah dikunci sebelumnya) agar bisa dihapus
if [ -f "$TARGET_FILE" ] || [ -d "$TARGET_FILE" ]; then
    echo "[+] Mendeteksi file lama, mencoba membuka atribut..."
    chattr -i "$TARGET_FILE" >/dev/null 2>&1 || true
    chmod 777 "$TARGET_FILE" >/dev/null 2>&1 || true
fi

# 2. Hapus file/folder tersebut sampai bersih
echo "[+] Menghapus file target: $TARGET_FILE"
rm -rf "$TARGET_FILE"

# 3. Pastikan direktori induknya ada
mkdir -p /etc/ssh/sshd_config.d

# 4. Buat file dummy kosong
echo "[+] Membuat file dummy kosong..."
touch "$TARGET_FILE"

# 5. Kunci Mati File Tersebut
# chmod 000 = Tidak ada yang boleh baca/tulis/eksekusi
# chattr +i = Immutable (Tidak bisa dihapus/diubah bahkan oleh root)
echo "[+] MENGUNCI FILE (Immutable + No Permission)..."
chmod 000 "$TARGET_FILE"
chattr +i "$TARGET_FILE"

# Verifikasi
if lsattr "$TARGET_FILE" | grep -q "i"; then
    echo "✅ SUKSES: File berhasil dikunci mati!"
else
    echo "⚠️ WARNING: Gagal memasang atribut immutable (cek support filesystem)."
fi

# 6. Membuat Script Pembuka Kunci (Unlocker) dengan Password
echo "[+] Membuat alat pembuka kunci di: $UNLOCK_TOOL"

cat > "$UNLOCK_TOOL" <<EOF
#!/bin/bash
TARGET="$TARGET_FILE"
PASS_BENAR="$MY_PASSWORD"

echo "============================================="
echo "   ALAT PEMBUKA KUNCI 01-permitrootlogin"
echo "============================================="
echo "File saat ini terkunci mati (Immutable)."
echo "Masukkan password untuk menghapus/membuka file ini."
echo ""
read -s -p "Password: " USER_PASS
echo ""

if [ "\$USER_PASS" == "\$PASS_BENAR" ]; then
    echo ""
    echo "🔓 Password Benar. Membuka kunci..."
    chattr -i "\$TARGET"
    chmod 644 "\$TARGET"
    echo "✅ File sekarang BISA diedit atau dihapus."
    echo "   Lokasi: \$TARGET"
else
    echo ""
    echo "❌ Password Salah! Akses ditolak."
    exit 1
fi
EOF

chmod +x "$UNLOCK_TOOL"

echo "====================================================="
echo "   SELESAI."
echo "   File target sekarang kosong dan TIDAK BISA DIEDIT."
echo "   Sistem/Update tidak akan bisa menimpa file ini."
echo ""
echo "   Untuk membuka kunci, gunakan perintah:"
echo "   $UNLOCK_TOOL"
echo "====================================================="
rm -f kunci-ssh.sh 2>/dev/null || true