#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo "Error: Silakan jalankan script ini sebagai root (gunakan sudo atau login sebagai root)."
    exit 1
fi

echo -e "\n[INFO] Memulai perbaikan konfigurasi Nginx dan HAProxy..."

# ==========================================
# 1. Fix Nginx Error
# ==========================================
echo "[INFO] Menghapus /etc/nginx/nginx.conf lama..."
rm -f /etc/nginx/nginx.conf

echo "[INFO] Mengunduh nginx.conf yang baru..."
wget -qO /etc/nginx/nginx.conf https://raw.githubusercontent.com/ica4me/auto-script-free/main/install/nginx.conf


# ==========================================
# 2. Fix HAProxy Error
# ==========================================
echo "[INFO] Menghapus /etc/haproxy/haproxy.cfg lama..."
rm -f /etc/haproxy/haproxy.cfg

echo "[INFO] Mengunduh haproxy.cfg yang baru..."
wget -qO /etc/haproxy/haproxy.cfg https://raw.githubusercontent.com/ica4me/auto-script-free/main/install/haproxy.cfg


# ==========================================
# 3. Restart Services
# ==========================================
echo "[INFO] Merestart layanan Nginx..."
systemctl restart nginx

echo "[INFO] Merestart layanan HAProxy..."
systemctl restart haproxy

# Cek status
if systemctl is-active --quiet nginx && systemctl is-active --quiet haproxy; then
    echo -e "\n[SUCCESS] Nginx dan HAProxy berhasil diperbaiki dan sedang berjalan!"
else
    echo -e "\n[WARNING] Script selesai, tetapi salah satu layanan (Nginx/HAProxy) mungkin masih gagal start. Cek dengan 'systemctl status nginx' atau 'systemctl status haproxy'."
fi