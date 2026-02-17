#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
SSH_DIR="/etc/ssh"
LOCK_TOOL="/usr/bin/edit-ssh"

echo "========================================================"
echo "   OTOMATISASI SSH: METODE REPLACE TOTAL"
echo "========================================================"

# 1. JEBOL KUNCI FOLDER & FILE (PENTING!)
echo "[+] Menjebol kunci folder /etc/ssh dan file config..."
# Buka kunci folder induknya dulu
chattr -R -i -a -u -e "$SSH_DIR" >/dev/null 2>&1
# Buka kunci file spesifik
chattr -i -a -u -e "$SSHD_CONFIG" >/dev/null 2>&1

# Cek apakah masih terkunci
if lsattr "$SSHD_CONFIG" | grep -q "[ia]"; then
    echo "    ⚠️ PERINGATAN: File masih terdeteksi terkunci!"
    echo "    🔨 Mencoba menghapus paksa..."
fi

# 2. BACKUP (Jika belum ada)
if [ -f "$SSHD_CONFIG" ] && [ ! -f "${SSHD_CONFIG}.bak" ]; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    echo "[+] Backup dibuat di ${SSHD_CONFIG}.bak"
fi

# 3. HAPUS FILE LAMA (JANGAN DIEDIT, HAPUS SAJA!)
echo "[+] Menghapus file konfigurasi lama..."
rm -f "$SSHD_CONFIG"

# Jika rm gagal, kosongkan isinya
if [ -f "$SSHD_CONFIG" ]; then
    echo -n > "$SSHD_CONFIG"
fi

# 4. BUAT FILE BARU DARI NOL (CLEAN CONFIG)
echo "[+] Menulis konfigurasi baru (Port 2026 & 2003)..."
cat > "$SSHD_CONFIG" <<EOF
# KONFIGURASI SSH BARU - XCCVME
# Dibuat otomatis oleh script sakti

# Port Custom
Port 2003
Port 2026

# Izin Login
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no

# Fitur Lain
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Banner (Jika ada)
Banner /etc/issue.net

ClientAliveInterval 10
ClientAliveCountMax 6
EOF

# Cek apakah file berhasil dibuat
if [ -s "$SSHD_CONFIG" ]; then
    echo "    ✅ Konfigurasi baru berhasil dibuat."
else
    echo "    ❌ GAGAL MEMBUAT FILE BARU! Cek izin folder /etc/ssh."
    exit 1
fi

# 5. RESTART SERVICE SSH
echo "[+] Merestart service SSH..."
service ssh restart >/dev/null 2>&1
service sshd restart >/dev/null 2>&1
systemctl restart ssh >/dev/null 2>&1
systemctl restart sshd >/dev/null 2>&1

# 6. KUNCI MATI (SUPER LOCK)
echo "[+] Mengaktifkan SUPER LOCK (+i)..."
chattr +i "$SSHD_CONFIG"

if lsattr "$SSHD_CONFIG" | grep -q "i"; then
    echo "    🔒 SUKSES: File BERHASIL dikunci Mati."
else
    echo "    ⚠️ Gagal mengunci file."
fi

# 7. MEMBUAT ALAT EDIT KHUSUS
echo "[+] Membuat alat edit aman: $LOCK_TOOL"
rm -f "$LOCK_TOOL"
cat > "$LOCK_TOOL" <<EOF
#!/bin/bash
TARGET="/etc/ssh/sshd_config"

echo "==================================================="
echo "   SECURE SSH EDITOR"
echo "==================================================="
read -s -p "Masukkan Password Admin (xccvme): " MYPASS
echo ""

if [ "\$MYPASS" == "xccvme" ]; then
    echo "🔓 Membuka kunci..."
    chattr -i -a \$TARGET
    
    echo "📝 Membuka NANO..."
    nano \$TARGET
    
    echo "🔒 Mengunci kembali..."
    chattr +i \$TARGET
    
    echo "🔄 Restart SSH..."
    service ssh restart >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1
    echo "✅ Selesai."
else
    echo "❌ PASSWORD SALAH!"
    exit 1
fi
EOF

chmod +x "$LOCK_TOOL"

echo "========================================================"
echo "   SELESAI. COBA LOGIN VIA PORT 2026 / 2003"
echo "========================================================"