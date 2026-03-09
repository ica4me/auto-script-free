#!/bin/bash

# ==========================================
# KONFIGURASI TELEGRAM BOT
# ==========================================
TOKEN="8260557422:AAFmxRgYnNNrXXwi6JqM_tmaCq8Xq_Ls4D0"
CHAT_ID="6663648335"

echo "==> [1/4] Menginstal modul Auditd, inotify, e2fsprogs (chattr)..."
apt-get update -qq
apt-get install -y auditd inotify-tools curl jq e2fsprogs

echo "==> [2/4] Memasang CCTV Kernel (Auditd) Super Ketat..."
auditctl -D
# Pantau password root
auditctl -w /etc/shadow -p wa -k password_changed
# Pantau direktori SSH dari segala jenis perubahan atribut, tulis, dan pergantian file (sed -i)
auditctl -w /etc/ssh/ -p wa -k ssh_config_changed

sh -c "auditctl -l > /etc/audit/rules.d/audit.rules"
systemctl restart auditd

echo "==> [3/4] Membuat Skrip Alarm & Auto-Heal Real-Time..."
cat << 'EOF' > /usr/local/bin/system-health-monitor.sh
#!/bin/bash

TOKEN="8260557422:AAFmxRgYnNNrXXwi6JqM_tmaCq8Xq_Ls4D0"
CHAT_ID="6663648335"
SERVICES=("udp-custom" "xray" "openvpn" "dropbear" "haproxy" "nginx" "cron")

send_tg() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"$CHAT_ID\", \"text\": \"$message\"}" > /dev/null
}

send_tg "🛡️ Sistem Audit PRO Aktif!\n\nDilengkapi pelindung anti-sed, anti-chattr, dan Auto-Heal. Jika ada sabotase, saya akan lapor dan langsung perbaiki sendiri!"

# =======================================
# 1. LOOP PANTAU SERVICE MATI
# =======================================
monitor_services() {
    declare -A STATE
    for s in "${SERVICES[@]}"; do
        STATE[$s]=$(systemctl is-active $s)
    done

    while true; do
        sleep 5
        for s in "${SERVICES[@]}"; do
            current=$(systemctl is-active $s)
            if [[ "${STATE[$s]}" == "active" && "$current" != "active" ]]; then
                send_tg "⚠️ ALERT: SERVICE DIMATIKAN!\n\nLayanan '$s' baru saja di-stop secara paksa."
            fi
            STATE[$s]=$current
        done
    done
}

# =======================================
# 2. LOOP PANTAU FILE (ANTI SED & CHATTR)
# =======================================
monitor_files() {
    # Pantau berbagai jenis event: modifikasi, ganti atribut (chattr), file ditimpa (sed -i)
    inotifywait -m -e modify,attrib,close_write,moved_to,create /etc/shadow /etc/ssh/ /etc/ssh/sshd_config.d/ 2>/dev/null |
    while read -r directory events filename; do
        filepath="$directory$filename"
        
        # Jeda sejenak agar proses sed/chattr pelaku selesai dan auditd selesai mencatat
        sleep 1 
        
        # JIKA PASSWORD ROOT DIUBAH
        if [[ "$filepath" == *"/shadow"* ]]; then
            CULPRIT=$(ausearch -k password_changed -ts recent | grep "exe=" | tail -1 | sed -E 's/.*exe="([^"]+)".*/\1/')
            send_tg "🚨 ALERT: PASSWORD ROOT DIUBAH!\n\nTersangka (Program): ${CULPRIT:-Unknown}"
        fi
        
        # JIKA KONFIGURASI SSH DIUBAH/DISABOTASE
        if [[ "$filepath" == *"/sshd_config"* || "$filepath" == *"/99-allow-root.conf"* ]]; then
            
            # Pengecekan apakah PasswordAuth dimatikan oleh pelaku
            if grep -Eqi "^[#]*PasswordAuthentication\s+no" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null; then
                
                # Cari tau dalangnya
                CULPRIT=$(ausearch -k ssh_config_changed -ts recent | grep "exe=" | tail -1 | sed -E 's/.*exe="([^"]+)".*/\1/')
                
                send_tg "🚨 SABOTASE SSH TERDETEKSI!\n\nPelaku menggunakan $events pada file $filename.\nProgram tersanga: ${CULPRIT:-Unknown}\n\n⚙️ Melakukan Auto-Recovery sekarang..."

                # ==========================================
                # PROSES AUTO-HEAL (PERBAIKAN OTOMATIS)
                # ==========================================
                # 1. Buka gembok file jika sebelumnya dikunci pelaku
                chattr -i /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
                
                # 2. Hapus aturan jahat menggunakan sed kita sendiri
                sed -i 's/^[#]*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
                sed -i 's/^[#]*PubkeyAuthentication.*/PubkeyAuthentication no/g' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
                
                # 3. Timpa paksa file drop-in config untuk memastikan
                echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-allow-root.conf
                echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-allow-root.conf
                echo "PubkeyAuthentication no" >> /etc/ssh/sshd_config.d/99-allow-root.conf
                
                # 4. Gembok kembali file tersebut dengan chattr +i agar pelaku pusing
                chattr +i /etc/ssh/sshd_config /etc/ssh/sshd_config.d/99-allow-root.conf
                
                # 5. Restart layanan SSH
                systemctl restart ssh
                
                send_tg "✅ RECOVERY SUKSES!\n\nPasswordAuthentication berhasil dikembalikan ke 'yes'.\nFile konfigurasi sekarang DIGEMBOK (chattr +i) untuk mencegah serangan lanjutan."
            fi
        fi
    done
}

monitor_services &
monitor_files &
wait
EOF

chmod +x /usr/local/bin/system-health-monitor.sh

echo "==> [4/4] Restart Service Background..."
cat << 'EOF' > /etc/systemd/system/system-health-monitor.service
[Unit]
Description=System Health & Security Monitor PRO
After=network.target

[Service]
ExecStart=/usr/local/bin/system-health-monitor.sh
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable system-health-monitor
systemctl restart system-health-monitor

echo "✅ SELESAI! Bot pantau ANTI-SED sudah berjalan penuh."