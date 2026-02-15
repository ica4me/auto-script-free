#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
LOCK_TOOL="/usr/bin/edit-ssh"

echo "========================================================"
echo "   OTOMATISASI SSH + SUPER LOCK (AGRESIF)"
echo "========================================================"

# 1. JEBOL KUNCI (FORCE UNLOCK)
# Membuka atribut Immutable (i), Append Only (a), Undeletable (u), dan Extent (e)
echo "[+] Menjebol semua atribut pengunci file..."
chattr -i -a -u -e "$SSHD_CONFIG" >/dev/null 2>&1
lsattr "$SSHD_CONFIG"

# 2. BACKUP AMAN
if [ -f "$SSHD_CONFIG" ]; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    echo "[+] Backup dibuat di ${SSHD_CONFIG}.bak"
fi

# 3. REKONSTRUKSI KONFIGURASI (AGAR BERSIH)
echo "[+] Menulis ulang konfigurasi SSH..."

# Kita hapus baris port lama dan settingan duplikat untuk memastikan bersih
sed -i '/^Port/d' "$SSHD_CONFIG"
sed -i '/^PermitRootLogin/d' "$SSHD_CONFIG"
sed -i '/^PasswordAuthentication/d' "$SSHD_CONFIG"
sed -i '/^PubkeyAuthentication/d' "$SSHD_CONFIG"
sed -i '/^ChallengeResponseAuthentication/d' "$SSHD_CONFIG"
sed -i '/^UsePAM/d' "$SSHD_CONFIG"

# Masukkan konfigurasi 'Sakti' di baris paling atas (sed 1i insert)
# Teknik ini mencegah konflik dengan konfigurasi default di bawahnya
sed -i '1i Port 2003\nPort 2026\nPermitRootLogin yes\nPasswordAuthentication yes\nPubkeyAuthentication no\nChallengeResponseAuthentication no\nUsePAM yes' "$SSHD_CONFIG"

echo "[+] Konfigurasi SSH diperbarui (Port 2026 & 2003)."

# 4. RESTART SERVICE SSH (FORCE RESTART)
echo "[+] Merestart service SSH..."
# Coba segala cara restart agar sukses
service ssh restart >/dev/null 2>&1
service sshd restart >/dev/null 2>&1
systemctl restart ssh >/dev/null 2>&1
systemctl restart sshd >/dev/null 2>&1

# 5. PENGUNCIAN PERMANEN (IMMUTABLE LOCK)
echo "[+] Mengaktifkan SUPER LOCK (+i)..."
chattr +i "$SSHD_CONFIG"

# Verifikasi kunci
if lsattr "$SSHD_CONFIG" | grep -q "i"; then
    echo "    🔒 SUKSES: File BERHASIL dikunci Mati."
else
    echo "    ⚠️ PERINGATAN: Gagal mengunci file. Cek sistem file Anda."
fi

# 6. MEMBUAT ALAT EDIT KHUSUS (edit-ssh)
echo "[+] Membuat alat edit aman: $LOCK_TOOL"
rm -f "$LOCK_TOOL" # Hapus jika ada versi lama
cat > "$LOCK_TOOL" <<EOF
#!/bin/bash
TARGET="/etc/ssh/sshd_config"

echo "==================================================="
echo "   SECURE SSH EDITOR (SUPER USER)"
echo "   File ini dilindungi (Immutable)."
echo "==================================================="
read -s -p "Masukkan Password Admin (xccvme): " MYPASS
echo ""

if [ "\$MYPASS" == "xccvme" ]; then
    echo "🔓 Password Benar. Membuka kunci sementara..."
    chattr -i -a \$TARGET
    
    echo "📝 Membuka NANO..."
    nano \$TARGET
    
    echo "🔒 Mengunci kembali file..."
    chattr +i \$TARGET
    
    echo "🔄 Merestart SSH Service..."
    service ssh restart >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1
    
    echo "✅ Selesai. File aman kembali."
else
    echo "❌ PASSWORD SALAH! Akses ditolak."
    echo "   File tetap terkunci dan tidak bisa diedit."
    exit 1
fi
EOF

# Beri izin eksekusi pada alat edit
chmod +x "$LOCK_TOOL"

echo "========================================================"
echo "   SELESAI. SILAKAN LOGIN VIA PORT 2026 / 2003"
echo "========================================================"
echo "⚠️  CATATAN:"
echo "1. Untuk mengedit SSH di masa depan, WAJIB gunakan perintah:"
echo "   👉 edit-ssh"
echo "   (Password: xccvme)"
echo "2. Script auto-install lain sekarang tidak akan bisa merusak settingan ini."
echo "========================================================"