#!/bin/bash
set -euo pipefail

# Pastikan script dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Error: Script ini harus dijalankan sebagai root (sudo)."
  exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
SSH_DIR="/etc/ssh"
SSHD_D_DIR="/etc/ssh/sshd_config.d"
BY_NAJM_URL="https://raw.githubusercontent.com/ica4me/auto-script-free/main/by_najm.conf"
BY_NAJM_FILE="${SSHD_D_DIR}/by_najm.conf"
LOCK_TOOL="/usr/bin/edit-ssh"

echo "========================================================"
echo "   OTOMATISASI SSH: REPLACE + INCLUDE OVERRIDE + LOCK"
echo "========================================================"

echo "[+] Membuka kunci (jika ada) /etc/ssh dan file config..."
chattr -R -i -a -u -e "$SSH_DIR" >/dev/null 2>&1 || true
chattr -i -a -u -e "$SSHD_CONFIG" >/dev/null 2>&1 || true
chattr -i -a -u -e "$BY_NAJM_FILE" >/dev/null 2>&1 || true

# Backup (Jika belum ada)
if [ -f "$SSHD_CONFIG" ] && [ ! -f "${SSHD_CONFIG}.bak" ]; then
  cp -a "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
  echo "[+] Backup dibuat di ${SSHD_CONFIG}.bak"
fi

# Hapus file lama lalu buat ulang
echo "[+] Menghapus file konfigurasi lama..."
rm -f "$SSHD_CONFIG"

echo "[+] Menulis konfigurasi baru (Port 2026 & 2003)..."
cat > "$SSHD_CONFIG" <<'EOF'
# KONFIGURASI SSH BARU - XCCVME
# Dibuat otomatis oleh script

# Port Custom
Port 22

# Izin Login
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no

# Fitur Lain
UsePAM yes
X11Forwarding yes
AcceptEnv LANG LC_*
ClientAliveInterval 10
ClientAliveCountMax 6

# Include
Include /etc/ssh/sshd_config.d/by_najm.conf
EOF

if [ ! -s "$SSHD_CONFIG" ]; then
  echo "❌ GAGAL MEMBUAT FILE BARU! Cek izin folder /etc/ssh."
  exit 1
fi
echo "    ✅ Konfigurasi baru berhasil dibuat."

# Pastikan directory sshd_config.d ada
echo "[+] Memastikan direktori ${SSHD_D_DIR} ada..."
mkdir -p "$SSHD_D_DIR"
chown root:root "$SSHD_D_DIR"
chmod 755 "$SSHD_D_DIR"

# Download by_najm.conf apa adanya
echo "[+] Mengunduh by_najm.conf -> ${BY_NAJM_FILE}"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$BY_NAJM_URL" -o "$BY_NAJM_FILE"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$BY_NAJM_FILE" "$BY_NAJM_URL"
  sed -i '/Subsystem sftp/d' /etc/ssh/sshd_config
else
  echo "❌ curl/wget tidak ditemukan. Install salah satunya."
  exit 1
fi

chown root:root "$BY_NAJM_FILE"
chmod 444 "$BY_NAJM_FILE"

# Tambahkan Include paling akhir agar override menimpa aturan sebelumnya
INCLUDE_LINE="Include ${BY_NAJM_FILE}"
echo "[+] Memastikan Include override ada di baris paling akhir sshd_config..."
# Hapus duplikat jika ada
grep -vF "$INCLUDE_LINE" "$SSHD_CONFIG" > "${SSHD_CONFIG}.tmp"
mv "${SSHD_CONFIG}.tmp" "$SSHD_CONFIG"
# Tambahkan di akhir
printf "\n%s\n" "$INCLUDE_LINE" >> "$SSHD_CONFIG"

# Validasi konfigurasi sshd sebelum restart (penting)
sed -i '/Subsystem sftp/d' /etc/ssh/sshd_config
echo "[+] Validasi konfigurasi sshd..."
if ! sshd -t -f "$SSHD_CONFIG"; then
  echo "❌ Konfigurasi sshd tidak valid. Membatalkan restart."
  echo "   Silakan cek file: $SSHD_CONFIG"
  exit 1
fi
echo "    ✅ Konfigurasi valid."

# Restart service SSH
echo "[+] Merestart service SSH..."
systemctl restart ssh >/dev/null 2>&1 || true
systemctl restart sshd >/dev/null 2>&1 || true
service ssh restart >/dev/null 2>&1 || true
service sshd restart >/dev/null 2>&1 || true

# Lock kuat: permission read-only + immutable
echo "[+] Mengaktifkan LOCK kuat (chmod 444 + chattr +i)..."
chown root:root "$SSHD_CONFIG"
chmod 444 "$SSHD_CONFIG"
chattr +i "$SSHD_CONFIG"
chattr +i "$BY_NAJM_FILE"

echo "[+] Membuat alat edit aman: $LOCK_TOOL"
rm -f "$LOCK_TOOL"

# Password admin diminta "xccvme" — simpan hash (bukan plaintext compare)
# sha256("xccvme") = 7d0f5a... (akan dihitung saat generate tool)
PASS_HASH="$(printf '%s' "xccvme" | sha256sum | awk '{print $1}')"

cat > "$LOCK_TOOL" <<EOF
#!/bin/bash
set -euo pipefail

TARGET="/etc/ssh/sshd_config"
OVERRIDE="/etc/ssh/sshd_config.d/by_najm.conf"
EXPECTED_HASH="${PASS_HASH}"

echo "==================================================="
echo "   SECURE SSH EDITOR"
echo "==================================================="
read -s -p "Masukkan Password Admin: " MYPASS
echo ""

INPUT_HASH=\$(printf '%s' "\$MYPASS" | sha256sum | awk '{print \$1}')

if [ "\$INPUT_HASH" != "\$EXPECTED_HASH" ]; then
  echo "❌ PASSWORD SALAH!"
  exit 1
fi

echo "🔓 Membuka kunci sementara..."
chattr -i "\$TARGET" 2>/dev/null || true
chattr -i "\$OVERRIDE" 2>/dev/null || true
chmod 600 "\$TARGET" "\$OVERRIDE"

EDITOR_BIN="\${EDITOR:-nano}"

echo "📝 Edit file utama: \$TARGET"
"\$EDITOR_BIN" "\$TARGET"

echo "📝 Edit file override: \$OVERRIDE"
"\$EDITOR_BIN" "\$OVERRIDE"

echo "✅ Validasi konfigurasi sshd..."
if ! sshd -t -f "\$TARGET"; then
  echo "❌ Konfigurasi tidak valid. Tidak akan restart. File tetap dibuka (tidak dikunci) agar bisa diperbaiki."
  exit 1
fi

echo "🔄 Restart SSH..."
systemctl restart ssh >/dev/null 2>&1 || true
systemctl restart sshd >/dev/null 2>&1 || true
service ssh restart >/dev/null 2>&1 || true
service sshd restart >/dev/null 2>&1 || true

echo "🔒 Mengunci kembali (chmod 444 + chattr +i)..."
chmod 444 "\$TARGET" "\$OVERRIDE"
chattr +i "\$TARGET"
chattr +i "\$OVERRIDE"

echo "✅ Selesai."
EOF

chmod 755 "$LOCK_TOOL"
chown root:root "$LOCK_TOOL"
rm -f ubah-ssh.sh 2>/dev/null || true
echo "========================================================"
echo "   SELESAI. SSH port: 2026 / 2003"
echo "   Override aktif: $BY_NAJM_FILE"
echo "   Editor aman: $LOCK_TOOL"
echo "========================================================"
