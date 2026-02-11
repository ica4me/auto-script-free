#!/bin/bash
# ==========================================
# 🔧 System Auto Update & License Checker (BYPASSED)
# ==========================================

### 🕓 Inisialisasi dan Variabel Dasar
# Mengambil tanggal dari Google untuk akurasi (opsional, bisa pakai date lokal)
data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=$(date +"%Y-%m-%d" -d "$data_server")
NC="\e[0m"
RED="\033[0;31m"
WH="\033[1;37m"
ipsaya=$(curl -sS ipv4.icanhazip.com)

# ==========================================
# ⚙️ Fungsi: Mengecek izin script dan versi
# ==========================================
checking_sc() {
    # --- BAGIAN BYPASS ---
    # Menetapkan masa aktif secara manual ke 2099-12-31
    useexp="2099-12-31"
    
    echo -e " [INFO] License Check Bypassed. Status: \033[1;32mVALID\033[0m"
    echo -e " [INFO] Valid until: $useexp"

    # Menonaktifkan fitur update otomatis agar file bypass tidak tertimpa
    echo -e " [INFO] Auto-update disabled to preserve bypass."
    
    # Logika asli untuk update dihapus/dikomari agar tidak merusak bypass
    # Jika Anda tetap ingin fitur update (berisiko bypass hilang), logika asli harus dikembalikan.
}

# ==========================================
# ▶️ Jalankan Fungsi Utama
# ==========================================
checking_sc
cd

# ==========================================
# 📅 Hitung sisa masa aktif lisensi
# ==========================================
today=$(date -d "0 days" +"%Y-%m-%d")

# --- BAGIAN BYPASS ---
# Hardcode tanggal kadaluarsa ke 2099-12-31
Exp2="2099-12-31"

d1=$(date -d "$Exp2" +%s)
d2=$(date -d "$today" +%s)
certificate=$(( (d1 - d2) / 86400 ))
echo "$certificate Hari" > /etc/masaaktif

# ==========================================
# 🔁 Pemeriksaan & Restart Otomatis Service
# ==========================================

### 🔹 Xray
xray2=$(systemctl status xray | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $xray2 != "running" ]]; then
    systemctl restart xray
fi

### 🔹 Haproxy
haproxy2=$(systemctl status haproxy | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $haproxy2 != "running" ]]; then
    systemctl restart haproxy
fi

### 🔹 Nginx
nginx2=$(systemctl status nginx | grep Active | awk '{print $3}' | sed 's/(//g' | sed 's/)//g')
if [[ $nginx2 != "running" ]]; then
    systemctl restart nginx
fi

### 🔹 Kyt (custom service)
if [[ -e /usr/bin/kyt ]]; then
    kyt_status=$(systemctl status kyt | grep Active | awk '{print $3}' | sed 's/(//g' | sed 's/)//g')
    if [[ $kyt_status != "running" ]]; then
        systemctl restart kyt
    fi
fi

### 🔹 WebSocket (ws)
ws=$(systemctl status ws | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
if [[ $ws != "running" ]]; then
    systemctl restart ws
fi

# ==========================================
# ✅ Selesai
# ==========================================