#!/bin/bash

# Pastikan script dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Error: Script ini harus dijalankan sebagai root (gunakan sudo su)."
   exit 1
fi

echo "=========================================================="
echo "   FIX RATE LIMIT LET'S ENCRYPT -> MIGRASI KE ZEROSSL"
echo "=========================================================="

# 1. Cek keberadaan file domain
if [ ! -f "/etc/xray/domain" ]; then
    echo "❌ Error: File /etc/xray/domain tidak ditemukan!"
    exit 1
fi
domain=$(cat /etc/xray/domain)
echo "➜ Menggunakan domain: $domain"

# 2. Hentikan service yang menggunakan port 80/443 sementara
# (Wajib dilakukan agar acme.sh --standalone tidak bentrok)
echo "➜ [1/6] Menghentikan Nginx & HAProxy sementara..."
systemctl stop nginx 2>/dev/null || true
systemctl stop haproxy 2>/dev/null || true

# 3. Daftarkan Email ke ZeroSSL
echo "➜ [2/6] Mendaftarkan akun ZeroSSL..."
/root/.acme.sh/acme.sh --register-account -m admin@najm.my.id --server zerossl

# 4. Ubah Default CA ke ZeroSSL
echo "➜ [3/6] Mengubah Default CA ke ZeroSSL..."
/root/.acme.sh/acme.sh --set-default-ca --server zerossl

# 5. Tembak Ulang Sertifikat
echo "➜ [4/6] Mengunduh sertifikat baru dari ZeroSSL..."
/root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --force

# 6. Install Sertifikat ke direktori Xray
echo "➜ [5/6] Memasang sertifikat ke Xray..."
/root/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc --force

# 7. Buat File Gabungan untuk HAProxy & Jalankan Service
echo "➜ [6/6] Konfigurasi HAProxy & Memulai ulang layanan..."
# Gabungkan crt dan key untuk format haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/hap.pem

# Nyalakan kembali semuanya
systemctl start nginx
systemctl start haproxy
systemctl restart xray

echo "=========================================================="
echo "✅ PROSES SELESAI! Menampilkan status HAProxy:"
echo "=========================================================="
# Tampilkan status terakhir
systemctl status haproxy --no-pager -l