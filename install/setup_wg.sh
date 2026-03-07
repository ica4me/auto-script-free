#!/bin/bash
# ==========================================
# setup_wg.sh
# Membuat helper prioritas WireGuard:
# - /usr/local/sbin/wg-priority-top
# - /etc/systemd/system/wg-priority-top.service
# - /etc/systemd/system/wg-priority-top.timer
#
# Tujuan:
# - jump ke WG_NAT_WG0 selalu di PREROUTING urutan #1
# - INPUT udp/<WG_PORT> selalu di urutan #1
#
# Pemakaian:
#   bash setup_wg.sh
#   bash setup_wg.sh 65535
#   bash setup_wg.sh 65535 eth0
# ==========================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WH='\033[1;37m'
NC='\033[0m'

WG_PORT="${1:-65535}"
PUB_IF_INPUT="${2:-}"
WG_CHAIN="WG_NAT_WG0"

WG_PRIORITY_BIN="/usr/local/sbin/wg-priority-top"
WG_PRIORITY_SERVICE="/etc/systemd/system/wg-priority-top.service"
WG_PRIORITY_TIMER="/etc/systemd/system/wg-priority-top.timer"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}        SETUP PRIORITAS IPTABLES WIREGUARD              ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo -e "${RED}[!] Jalankan script ini sebagai root.${NC}"
  exit 1
fi

# Deteksi interface publik bila tidak diberikan
if [[ -n "${PUB_IF_INPUT}" ]]; then
  PUB_IF="${PUB_IF_INPUT}"
else
  PUB_IF="$(ip -4 route list default 2>/dev/null | awk '{print $5}' | head -n1)"
fi

if [[ -z "${PUB_IF}" ]]; then
  echo -e "${RED}[!] Interface publik tidak terdeteksi.${NC}"
  exit 1
fi

echo -e "${GREEN}[+]${NC} Interface publik: ${YELLOW}${PUB_IF}${NC}"
echo -e "${GREEN}[+]${NC} Port WireGuard : ${YELLOW}${WG_PORT}${NC}"
echo -e "${GREEN}[+]${NC} Chain NAT      : ${YELLOW}${WG_CHAIN}${NC}"

# Pastikan dependency dasar ada
if ! command -v iptables >/dev/null 2>&1; then
  echo -e "${YELLOW}[!] iptables belum tersedia, mencoba instalasi...${NC}"
  apt update -y >/dev/null 2>&1 || true
  apt install -y iptables iproute2 >/dev/null 2>&1 || true
fi

# =========================================================
# 1) Buat helper script /usr/local/sbin/wg-priority-top
# =========================================================
echo -e "${GREEN}[+]${NC} Membuat helper ${YELLOW}${WG_PRIORITY_BIN}${NC} ..."

cat > "${WG_PRIORITY_BIN}" <<EOF
#!/bin/bash
set -euo pipefail

PUB_IF="\${1:-\$(ip -4 route list default 2>/dev/null | awk '{print \$5}' | head -n1)}"
WG_PORT="\${2:-${WG_PORT}}"
WG_CHAIN="${WG_CHAIN}"

[ -n "\${PUB_IF}" ] || exit 0

# Pastikan chain khusus WireGuard ada
iptables -t nat -N "\${WG_CHAIN}" 2>/dev/null || true

# Pastikan jump ke chain WG selalu paling atas di PREROUTING
while iptables -t nat -C PREROUTING -i "\${PUB_IF}" -j "\${WG_CHAIN}" >/dev/null 2>&1; do
  iptables -t nat -D PREROUTING -i "\${PUB_IF}" -j "\${WG_CHAIN}" >/dev/null 2>&1 || true
done
iptables -t nat -I PREROUTING 1 -i "\${PUB_IF}" -j "\${WG_CHAIN}"

# Pastikan rule INPUT udp/WG_PORT selalu paling atas
while iptables -C INPUT -p udp --dport "\${WG_PORT}" -j ACCEPT >/dev/null 2>&1; do
  iptables -D INPUT -p udp --dport "\${WG_PORT}" -j ACCEPT >/dev/null 2>&1 || true
done
iptables -I INPUT 1 -p udp --dport "\${WG_PORT}" -j ACCEPT
EOF

chmod +x "${WG_PRIORITY_BIN}"

# Jalankan sekali agar langsung aktif sekarang
"${WG_PRIORITY_BIN}" "${PUB_IF}" "${WG_PORT}" >/dev/null 2>&1 || true

# =========================================================
# 2) Buat service systemd
# =========================================================
echo -e "${GREEN}[+]${NC} Membuat service ${YELLOW}${WG_PRIORITY_SERVICE}${NC} ..."

cat > "${WG_PRIORITY_SERVICE}" <<EOF
[Unit]
Description=Re-assert WireGuard iptables priority
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${WG_PRIORITY_BIN} ${PUB_IF} ${WG_PORT}
EOF

# =========================================================
# 3) Buat timer systemd
# =========================================================
echo -e "${GREEN}[+]${NC} Membuat timer ${YELLOW}${WG_PRIORITY_TIMER}${NC} ..."

cat > "${WG_PRIORITY_TIMER}" <<EOF
[Unit]
Description=Run wg-priority-top periodically

[Timer]
OnBootSec=15s
OnUnitActiveSec=15s
Unit=wg-priority-top.service

[Install]
WantedBy=timers.target
EOF

# Reload systemd dan aktifkan timer
echo -e "${GREEN}[+]${NC} Mengaktifkan timer prioritas WireGuard..."
systemctl daemon-reload
systemctl enable --now wg-priority-top.timer

# Jalankan service sekali lagi untuk memastikan state final
systemctl start wg-priority-top.service >/dev/null 2>&1 || true

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ setup_wg.sh selesai.${NC}"
echo -e "${WH}Helper dibuat : ${YELLOW}${WG_PRIORITY_BIN}${NC}"
echo -e "${WH}Service dibuat: ${YELLOW}${WG_PRIORITY_SERVICE}${NC}"
echo -e "${WH}Timer dibuat  : ${YELLOW}${WG_PRIORITY_TIMER}${NC}"
echo -e "${WH}Port WG       : ${YELLOW}${WG_PORT}${NC}"
echo -e "${WH}Interface     : ${YELLOW}${PUB_IF}${NC}"
echo -e "${WH}Chain NAT     : ${YELLOW}${WG_CHAIN}${NC}"
echo -e "${WH}Status timer  : ${YELLOW}systemctl status wg-priority-top.timer${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"