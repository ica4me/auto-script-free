#!/bin/bash
# ======================================================
# INSTALLER AUTO-MONITOR UDPZI (EVERY 10 SECONDS)
# ======================================================

# 1. Buat Script Worker (Pengeksekusi)
cat << 'EOF' > /usr/local/sbin/udpzi-worker.sh
#!/bin/bash
# ======================================================
# UDPZI WORKER - ATOMIC UPDATE MODE (ANTI-EMPTY)
# ======================================================

while true; do
    # 1. Jalankan script dan simpan ke file temporary (.tmp)
    # File asli tidak akan tersentuh selama proses scanning 3-5 detik
    /usr/local/sbin/client-udpzi | sed -n '/📌 RINGKASAN PER AKUN:/,$p' > /var/tmp/udpzi-client-session.log.tmp
    
    # 2. Setelah data SELESAI dan READY, baru timpa file asli
    # Proses 'mv' ini terjadi dalam hitungan milidetik
    mv /var/tmp/udpzi-client-session.log.tmp /var/tmp/udpzi-client-session.log
    
    # Tunggu 10 detik sebelum pindaian berikutnya
    sleep 10
done
EOF

chmod +x /usr/local/sbin/udpzi-worker.sh

# 2. Buat Systemd Service File
cat << 'EOF' > /etc/systemd/system/udpzi-monitor.service
[Unit]
Description=UDPZI Real-time Session Monitor
After=network.target zivpn.service

[Service]
Type=simple
ExecStart=/usr/local/sbin/udpzi-worker.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 3. Aktifkan dan Jalankan Service
systemctl daemon-reload
systemctl enable udpzi-monitor
systemctl restart udpzi-monitor

echo "======================================================"
echo " ✅ Service udpzi-monitor berhasil diinstal!"
echo " 🕒 Status: Berjalan setiap 10 detik"
echo " 📂 Log: /var/tmp/udpzi-client-session.log"
echo "======================================================"