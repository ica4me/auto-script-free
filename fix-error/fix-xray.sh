#!/bin/bash

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo "Error: Silakan jalankan script ini sebagai root."
    exit 1
fi

echo -e "\n[INFO] Memulai perbaikan izin akses Xray..."

# 1. Berikan kepemilikan folder log dan isinya ke www-data
echo "[INFO] Menyesuaikan izin folder log (/var/log/xray)..."
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