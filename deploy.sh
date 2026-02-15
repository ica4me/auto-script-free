#!/bin/bash

# ==========================================
#  AUTO DEPLOYMENT + SECURITY INJECTION
# ==========================================

echo "[+] Memulai Update System..."
apt update -y
apt upgrade -y
apt install screen curl wget -y

echo "[+] Mendownload Script Setup Utama..."
wget -q https://raw.githubusercontent.com/ica4me/auto-script-free/main/setup.sh
chmod +x setup.sh

# ==========================================
#  LOGIKA INJEKSI (MAGIC PART)
#  Agar script perbaikan jalan OTOMATIS di dalam setup.sh
# ==========================================
echo "[+] Menyuntikkan Script 'Sakti' ke dalam setup.sh..."

# 1. Buat file sementara berisi perintah fix (menggunakan metode CURL)
cat > /root/run-fixes.sh <<EOF
#!/bin/bash
echo "============================================="
echo "   MENJALANKAN SCRIPT FIX & SECURITY..."
echo "============================================="
sleep 2
curl -sL https://raw.githubusercontent.com/ica4me/auto-script-free/main/ubah-ssh.sh | bash
curl -sL https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-profile.sh | bash
curl -sL https://raw.githubusercontent.com/ica4me/auto-script-free/main/reset-user.sh | bash
echo "============================================="
echo "   SEMUA FIX SELESAI. REBOOTING..."
echo "============================================="
sleep 2
EOF

chmod +x /root/run-fixes.sh

# 2. Cari perintah 'reboot' di setup.sh dan ganti dengan 'run-fixes.sh' lalu 'reboot'
# Ini memastikan fix jalan sebelum VPS mati/restart
if grep -q "reboot" setup.sh; then
    sed -i 's/reboot/bash \/root\/run-fixes.sh \&\& reboot/g' setup.sh
else
    # Jika tidak ada kata reboot, tempel di baris paling akhir
    echo "bash /root/run-fixes.sh" >> setup.sh
fi

echo "[+] Injeksi Selesai."

# ==========================================
#  EKSEKUSI SCREEN
# ==========================================
echo "[+] Menjalankan Setup di dalam Screen 'Xwan'..."
screen -S Xwan ./setup.sh