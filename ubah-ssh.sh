#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
LOCK_TOOL="/usr/bin/edit-ssh"

echo "========================================================"
echo "   OTOMATISASI SSH + SECURE LOCK (PASSWORD PROTECTED)"
echo "========================================================"

# 1. CEK DAN BUKA ATRIBUT IMMUTABLE (JIKA ADA)
echo "[+] Memeriksa status kunci file saat ini..."
if lsattr "$SSHD_CONFIG" 2>/dev/null | grep -q "i"; then
    echo "    🔓 File terkunci. Membuka kunci sementara..."
    chattr -i "$SSHD_CONFIG"
else
    # Pastikan bersih dari atribut i
    chattr -i "$SSHD_CONFIG" >/dev/null 2>&1
fi

# 2. BACKUP CONFIG ASLI
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# 3. MODIFIKASI KONFIGURASI
echo "[+] Mengubah settingan SSH..."

# A. Hapus Port Lama & Pasang Port Baru (2026 & 2003)
sed -i '/^[#[:space:]]*Port[[:space:]]/d' "$SSHD_CONFIG"
if grep -q "^Include" "$SSHD_CONFIG"; then
    sed -i '/^Include/a Port 2003\nPort 2026' "$SSHD_CONFIG"
else
    sed -i '1i Port 2003\nPort 2026' "$SSHD_CONFIG"
fi

# B. Setting Wajib
# PermitRootLogin -> yes
if grep -q "^[#[:space:]]*PermitRootLogin" "$SSHD_CONFIG"; then
    sed -i 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
else
    echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
fi

# PasswordAuthentication -> yes
if grep -q "^[#[:space:]]*PasswordAuthentication" "$SSHD_CONFIG"; then
    sed -i 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
else
    echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
fi

# PubkeyAuthentication -> no
if grep -q "^[#[:space:]]*PubkeyAuthentication" "$SSHD_CONFIG"; then
    sed -i 's/^[#[:space:]]*PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
else
    echo "PubkeyAuthentication no" >> "$SSHD_CONFIG"
fi

echo "[+] Konfigurasi SSH diperbarui."

# 4. RESTART SERVICE SSH (PENTING: Sebelum dikunci)
echo "[+] Merestart service SSH..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh
    systemctl restart sshd
else
    service ssh restart
fi

# 5. PENGUNCIAN PERMANEN (IMMUTABLE)
echo "[+] Mengaktifkan IMMUTABLE LOCK (+i)..."
chattr +i "$SSHD_CONFIG"

if lsattr "$SSHD_CONFIG" | grep -q "i"; then
    echo "    🔒 File BERHASIL dikunci."
else
    echo "    ⚠️ Gagal mengunci file."
fi

# 6. MEMBUAT ALAT EDIT KHUSUS (edit-ssh)
echo "[+] Membuat alat edit aman: $LOCK_TOOL"
cat > "$LOCK_TOOL" <<EOF
#!/bin/bash
TARGET="/etc/ssh/sshd_config"

echo "==================================================="
echo "   SECURE SSH EDITOR"
echo "   File ini dilindungi (Immutable)."
echo "==================================================="
read -s -p "Masukkan Password Admin (xccvme): " MYPASS
echo ""

if [ "\$MYPASS" == "xccvme" ]; then
    echo "🔓 Password Benar. Membuka kunci sementara..."
    chattr -i \$TARGET
    
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
echo "   KONFIGURASI SELESAI"
echo "========================================================"
echo "⚠️  PENTING:"
echo "1. File '/etc/ssh/sshd_config' sekarang TERKUNCI (+i)."
echo "2. Script auto-install lain TIDAK AKAN BISA mengubahnya."
echo "3. Jika Anda ingin mengedit SSH, GUNAKAN PERINTAH:"
echo "   👉 edit-ssh"
echo "   (Password: xccvme)"
echo "========================================================"