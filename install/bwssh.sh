#!/bin/bash
# ╔══════════════════════════════════════════════════════════╗
# ║ 🛰️  SSH Live Bandwidth Monitor v1.0                      ║
# ║ ⚙️  Developer : NAJM STORE                               ║
# ║ 📡  Fungsi    : Monitor real-time traffic per user SSH   ║
# ╚══════════════════════════════════════════════════════════╝

# 🎨 WARNA
NC="\e[0m"
RED="\e[31m"
GRN="\e[32m"
YLW="\e[33m"
BLU="\e[34m"
CYN="\e[36m"
WHT="\e[37m"

# ==========================================================
# 📁 KONFIGURASI DASAR
# ==========================================================
LOG_FILE="/tmp/login.db"

# Pastikan log file tersedia
if [[ ! -f "$LOG_FILE" ]]; then
    echo -e "${RED}✖ File log tidak ditemukan: $LOG_FILE${NC}"
    exit 1
fi

declare -A user_ips

# ==========================================================
# 🧩 FUNCTION: Parse_Log_File
# → Membaca log dan memetakan user dengan IP & port
# ==========================================================
Parse_Log_File() {
    while IFS= read -r line; do
        # Contoh format: 2347373 - 'Taryadi' - 127.0.0.1:34834
        user=$(echo "$line" | awk -F"'" '{print $2}')
        ip=$(echo "$line" | awk -F" - " '{print $3}' | cut -d':' -f1)
        port=$(echo "$line" | awk -F":" '{print $NF}')
        user_ips["$user"]="$ip:$port"
    done < "$LOG_FILE"
}

# ==========================================================
# 📊 FUNCTION: Monitor_Traffic
# → Mengecek bandwidth per user setiap 10 detik
# ==========================================================
Monitor_Traffic() {
    clear
    echo -e "${CYN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYN}║ 🔍 SSH BANDWIDTH MONITOR — Live Mode                 ║${NC}"
    echo -e "${CYN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    while true; do
        echo -e "${BLU}┌──────────────────────────────────────────────────────┐${NC}"
        printf "${WHT}│ %-15s │ %-20s │ %-12s │ %-12s │${NC}\n" "User" "IP:Port" "Sent (bytes)" "Recv (bytes)"
        echo -e "${BLU}├──────────────────────────────────────────────────────┤${NC}"

        for user in "${!user_ips[@]}"; do
            ip_port="${user_ips[$user]}"
            ip=$(echo "$ip_port" | cut -d':' -f1)
            port=$(echo "$ip_port" | cut -d':' -f2)

            # Gunakan ss untuk ambil statistik koneksi
            traffic_info=$(ss -i state established "( dport = :$port ) or ( sport = :$port )")

            # Ambil data byte yang dikirim & diterima
            bytes_sent=$(echo "$traffic_info" | grep -oP 'bytes_sent:\K\d+' | head -1)
            bytes_received=$(echo "$traffic_info" | grep -oP 'bytes_received:\K\d+' | head -1)

            # Jika tidak ada data, isi 0
            bytes_sent=${bytes_sent:-0}
            bytes_received=${bytes_received:-0}

            # Tampilkan hasil dengan format tabel
            printf "${YLW}│ %-15s │ %-20s │ %-12s │ %-12s │${NC}\n" "$user" "$ip_port" "$bytes_sent" "$bytes_received"
        done

        echo -e "${BLU}└──────────────────────────────────────────────────────┘${NC}"
        echo -e "${GRN}⏳ Update berikutnya dalam 10 detik...${NC}"
        sleep 10
        clear
        echo -e "${CYN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYN}║ 🔍 SSH BANDWIDTH MONITOR — Refreshing Data...       ║${NC}"
        echo -e "${CYN}╚══════════════════════════════════════════════════════╝${NC}"
        echo ""
    done
}

# ==========================================================
# 🚀 EKSEKUSI UTAMA
# ==========================================================
Parse_Log_File
Monitor_Traffic
