#!/bin/bash
# ==================================================
# UDP Custom Installer (FIXED & CLEAN)
# ==================================================

# Pindah ke root directory dan buat folder untuk UDP
cd
mkdir -p /root/udp

# Set timezone ke GMT+7 (Jakarta)
echo "📅 Setting timezone ke GMT+7..."
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ==================================================
# Download udp-custom binary dari GITHUB SENDIRI
# ==================================================
echo "⬇️  Mengunduh udp-custom bersih..."
# GANTI LINK DI BAWAH DENGAN LINK RAW GITHUB ANDA
wget -q --show-progress "https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/instal_deteksi" -O /root/udp/udp-custom
chmod +x /root/udp/udp-custom

# Download default config dari GITHUB SENDIRI
echo "⬇️  Mengunduh konfigurasi default..."
# GANTI LINK DI BAWAH DENGAN LINK RAW GITHUB ANDA
wget -q --show-progress "https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/config.json" -O /root/udp/config.json
chmod 644 /root/udp/config.json

# ==================================================
# Setup systemd service
# ==================================================
echo "⚙️  Membuat service systemd udp-custom..."
SERVICE_FILE="/etc/systemd/system/udp-custom.service"

if [ -z "$1" ]; then
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=UDP Custom by ePro Dev. Team

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF
else
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=UDP Custom by ePro Dev. Team

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server -exclude $1
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF
fi

# ==================================================
# Start & enable service
# ==================================================
echo "🚀 Menjalankan service udp-custom..."
systemctl daemon-reload
systemctl start udp-custom
systemctl enable udp-custom