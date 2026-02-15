#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "========================================================"
echo "   OTOMATISASI KONFIGURASI SSH (PORT 2026 & 2003)"
echo "========================================================"

# 1. CEK DAN BUKA ATRIBUT IMMUTABLE
echo "[+] Memeriksa atribut file $SSHD_CONFIG..."
if lsattr "$SSHD_CONFIG" 2>/dev/null | grep -q "i"; then
    echo "    ⚠️ File terdeteksi IMMUTABLE (Terproteksi)."
    echo "    🔓 Mencoba membuka paksa kunci immutable..."
    chattr -i "$SSHD_CONFIG"
    if [ $? -eq 0 ]; then
        echo "    ✅ Berhasil membuka kunci."
    else
        echo "    ❌ Gagal membuka kunci. Pastikan Anda menggunakan root/VPS support chattr."
        exit 1
    fi
else
    # Jaga-jaga tetap jalankan chattr -i untuk memastikan
    chattr -i "$SSHD_CONFIG" >/dev/null 2>&1
    echo "    ✅ File status normal (Writable)."
fi

# 2. BACKUP CONFIG ASLI
echo "[+] Membuat backup konfigurasi asli ke ${SSHD_CONFIG}.bak"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# 3. MODIFIKASI KONFIGURASI
echo "[+] Mengubah settingan SSH..."

# A. HAPUS SEMUA PORT LAMA (Aktif maupun dikomentar)
sed -i '/^[#[:space:]]*Port[[:space:]]/d' "$SSHD_CONFIG"

# B. TAMBAHKAN PORT BARU (2026 & 2003)
# Kita tambahkan di bagian atas file (setelah baris Include jika ada, atau paling atas)
if grep -q "^Include" "$SSHD_CONFIG"; then
    sed -i '/^Include/a Port 2003\nPort 2026' "$SSHD_CONFIG"
else
    # Jika tidak ada Include, taruh paling atas
    sed -i '1i Port 2003\nPort 2026' "$SSHD_CONFIG"
fi

# C. UBAH PermitRootLogin -> yes
if grep -q "^[#[:space:]]*PermitRootLogin" "$SSHD_CONFIG"; then
    sed -i 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
else
    echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
fi

# D. UBAH PasswordAuthentication -> yes
if grep -q "^[#[:space:]]*PasswordAuthentication" "$SSHD_CONFIG"; then
    sed -i 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
else
    echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
fi

# E. UBAH PubkeyAuthentication -> no
if grep -q "^[#[:space:]]*PubkeyAuthentication" "$SSHD_CONFIG"; then
    sed -i 's/^[#[:space:]]*PubkeyAuthentication.*/PubkeyAuthentication no/' "$SSHD_CONFIG"
else
    echo "PubkeyAuthentication no" >> "$SSHD_CONFIG"
fi

# Tambahan: Matikan UsePAM jika ingin full password auth (opsional, kadang perlu di beberapa vps)
# sed -i 's/^[#[:space:]]*UsePAM.*/UsePAM no/' "$SSHD_CONFIG"

echo "[+] Konfigurasi selesai diterapkan."

# 4. RESTART SERVICE SSH
echo "[+] Merestart service SSH..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh
    systemctl restart sshd
elif command -v service >/dev/null 2>&1; then
    service ssh restart
    service sshd restart
else
    /etc/init.d/ssh restart
fi

# 5. VERIFIKASI
echo "========================================================"
echo "   VERIFIKASI HASIL"
echo "========================================================"
echo "Port yang aktif:"
grep "^Port" "$SSHD_CONFIG"
echo "Root Login:"
grep "^PermitRootLogin" "$SSHD_CONFIG"
echo "Auth Password:"
grep "^PasswordAuthentication" "$SSHD_CONFIG"
echo "Auth Pubkey:"
grep "^PubkeyAuthentication" "$SSHD_CONFIG"
echo "========================================================"
echo "✅ Silakan coba login ssh via Port 2026 atau 2003."