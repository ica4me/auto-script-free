#!/bin/bash

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo "Error: Silakan jalankan script ini sebagai root."
    exit 1
fi

echo -e "\n[INFO] Memulai perbaikan konfigurasi dan izin akses Xray..."

# 0. Download dan timpa file config.json
echo "[INFO] Mengunduh config.json baru dari Github..."
rm -f /etc/xray/config.json
wget -qO /etc/xray/config.json "https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/xray-config.json"

if [ ! -f /etc/xray/config.json ]; then
    echo "[ERROR] Gagal mengunduh file config.json. Silakan cek koneksi internet."
    exit 1
fi

# Mengatur izin full (777) ke file config.json sesuai permintaan
echo "[INFO] Mengatur izin akses penuh pada file /etc/xray/config.json..."
chmod 777 /etc/xray/config.json

# 1. Berikan kepemilikan folder log dan isinya ke www-data
echo "[INFO] Menyesuaikan izin folder log (/var/log/xray)..."
mkdir -p /var/log/xray # Memastikan folder log ada
chown -R www-data:www-data /var/log/xray

# 2. Berikan kepemilikan folder konfigurasi ke www-data
echo "[INFO] Menyesuaikan izin folder konfigurasi (/etc/xray)..."
chown -R www-data:www-data /etc/xray

# 3. Restart layanan Xray
echo "[INFO] Mereload daemon dan merestart layanan Xray..."
systemctl daemon-reload
systemctl restart xray

echo -e "[SUCCESS] Perbaikan selesai!\n"
echo "Berikut adalah status layanan Xray saat ini:"
echo "------------------------------------------------"

# 4. Cek statusnya
systemctl status xray --no-pager