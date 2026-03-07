#!/bin/bash
# ==========================================
# Auto Installer Service Quota Limit XRAY
# OS Support: Debian & Ubuntu
# ==========================================

# Warna Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}       AUTO INSTALLER SERVICE QUOTA XRAY            ${NC}"
echo -e "${CYAN}====================================================${NC}"

# 1. Pastikan dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Error: Script ini harus dijalankan sebagai root!${NC}"
    echo -e "Gunakan perintah: sudo bash $0"
    exit 1
fi

# 2. Pastikan file /usr/local/sbin/quota benar-benar ada
QUOTA_BIN="/usr/local/sbin/quota"
if [ ! -f "$QUOTA_BIN" ]; then
    echo -e "${RED}Error: File executable $QUOTA_BIN tidak ditemukan!${NC}"
    echo -e "${YELLOW}Pastikan script quota sudah diletakkan di folder tersebut.${NC}"
    exit 1
fi

# Berikan hak akses eksekusi penuh ke file quota
chmod +x "$QUOTA_BIN"

# 3. Daftar protokol yang akan dibuatkan servicenya
PROTOCOLS=("vmess" "vless" "trojan" "shadowsocks")

echo -e "${GREEN}[*] Memulai pembuatan file Systemd Service...${NC}"

# Loop untuk membuat file service
for PROTO in "${PROTOCOLS[@]}"; do
    SERVICE_NAME="quota-${PROTO}"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    # Mengubah nama protokol jadi HURUF KAPITAL untuk Deskripsi
    PROTO_UPPER=$(echo "$PROTO" | tr '[:lower:]' '[:upper:]')

    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Monitor Quota XRAY ${PROTO_UPPER}
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${QUOTA_BIN} ${PROTO}
Restart=always
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    echo -e " - ${CYAN}Created:${NC} ${SERVICE_FILE}"
done

echo -e "\n${GREEN}[*] Merefresh Systemd Daemon...${NC}"
systemctl daemon-reload

echo -e "${GREEN}[*] Mengaktifkan dan Menjalankan Service...${NC}"
# Loop untuk enable (auto-boot) dan start service
for PROTO in "${PROTOCOLS[@]}"; do
    SERVICE_NAME="quota-${PROTO}"
    
    # Enable agar otomatis jalan saat server reboot
    systemctl enable "${SERVICE_NAME}" >/dev/null 2>&1
    
    # Start service sekarang
    systemctl restart "${SERVICE_NAME}"
    
    # Cek status memastikan running
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo -e " - Service ${YELLOW}${SERVICE_NAME}${NC} : ${GREEN}[ RUNNING & ENABLED ]${NC}"
    else
        echo -e " - Service ${YELLOW}${SERVICE_NAME}${NC} : ${RED}[ FAILED TO START ]${NC}"
    fi
done

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}  ✅ Instalasi Service Quota Selesai 100% ✅        ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "Semua service sekarang akan otomatis hidup saat server di-reboot."