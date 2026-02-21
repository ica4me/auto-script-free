#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║    ⛓️  D£VSX-NETWORK :: SYSTEM BOOTSTRAP & OPTIMIZE (BYPASSED)    ║
# ╚══════════════════════════════════════════════════════════════════╝
set -o errexit
set -o nounset
set -o pipefail

# ---------------------------
# 🎨 Colors & helpers
# ---------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR ]${NC} $*"; exit 1; }

# ---------------------------
# ⚙️ Vars & repo
# ---------------------------
# PENTING: GANTI URL DI BAWAH INI KE REPO GITHUB ANDA SENDIRI
REPO="https://raw.githubusercontent.com/ica4me/auto-script-free/main/"
export DEBIAN_FRONTEND=noninteractive

# Network Interface
NET_IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1 || echo "eth0")
MYIP=$(wget -qO- ipinfo.io/ip || curl -sS https://ipv4.icanhazip.com || echo "0.0.0.0")
MYIP_PLACEHOLDER="s/xxxxxxxxx/${MYIP}/g"

# ---------------------------
# 0) Quick header
# ---------------------------
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}   ⛓️  VPS SETUP (MODIFIED & BYPASSED VERSION)                ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo

# ---------------------------
# 1) System update & essentials
# ---------------------------
info "Updating system packages..."
apt update -y >/dev/null 2>&1 || true
apt upgrade -y >/dev/null 2>&1 || true
ok "System updated"

info "Installing essential packages..."
PKGS=(screen curl jq bzip2 gzip vnstat coreutils rsyslog iftop zip unzip git apt-transport-https build-essential netfilter-persistent figlet ruby lolcat php php-fpm php-cli php-mysql libxml-parser-perl neofetch lsof htop net-tools wget nano sed gnupg bc dirmngr)
apt-get install -y "${PKGS[@]}" >/dev/null 2>&1 || warn "Some packages failed."
ok "Essential packages installed"

if ! command -v lolcat >/dev/null 2>&1; then
  gem install lolcat >/dev/null 2>&1 || warn "lolcat install failed"
fi

# ---------------------------
# 2) Remove unwanted services
# ---------------------------
apt-get remove --purge -y ufw firewalld >/dev/null 2>&1 || true

# ---------------------------
# 3) rc.local setup
# ---------------------------
cat > /etc/systemd/system/rc-local.service <<'EOF'
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/rc.local <<'EOF'
#!/bin/sh -e
exit 0
EOF
chmod +x /etc/rc.local
systemctl daemon-reload
systemctl enable --now rc-local.service >/dev/null 2>&1 || true

# ---------------------------
# 4) Disable IPv6
# ---------------------------
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6 || true
if ! grep -q "disable_ipv6" /etc/rc.local 2>/dev/null; then
  sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
fi

# ---------------------------
# 5) Webstack: nginx
# ---------------------------
info "Installing Nginx..."
apt-get install -y nginx certbot >/dev/null 2>&1
if wget -q -O /etc/nginx/nginx.conf "${REPO}install/nginx.conf"; then ok "nginx.conf fetched"; fi
if wget -q -O /etc/nginx/conf.d/vps.conf "${REPO}install/vps.conf"; then ok "vps.conf fetched"; fi

sed -i 's@listen = /var/run/php-fpm.sock@listen = 127.0.0.1:9000@g' /etc/php/*/fpm/pool.d/* 2>/dev/null || true

mkdir -p /home/vps/public_html
echo "<?php phpinfo(); ?>" > /home/vps/public_html/info.php
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html

# MODIFIED: Create clean index file
echo "<h1>VPS RUNNING - BYPASSED</h1>" > /home/vps/public_html/index.html
systemctl restart nginx >/dev/null 2>&1 || true

# ---------------------------
# 6) badvpn
# ---------------------------
wget -q -O /usr/sbin/badvpn "${REPO}install/badvpn" || warn "badvpn fetch failed"
chmod +x /usr/sbin/badvpn || true
for i in 1 2 3; do
  wget -q -O "/etc/systemd/system/badvpn${i}.service" "${REPO}install/badvpn${i}.service" && systemctl enable --now badvpn${i} >/dev/null 2>&1 || true
done

# ---------------------------
# 7) SSH & Dropbear
# ---------------------------
info "Configuring SSH..."
SSH_CONF='/etc/ssh/sshd_config'
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' "$SSH_CONF" || true
sed -i '/^Port /d' "$SSH_CONF"
# IMPORTANT: Port 22 must be present
cat >> "$SSH_CONF" <<'EOF'
Port 22
Port 2222
Port 2082
Port 40000
EOF
systemctl restart ssh >/dev/null 2>&1 || true

info "Configuring Dropbear..."
apt-get install -y dropbear >/dev/null 2>&1
wget -q -O /etc/default/dropbear "${REPO}install/dropbear" || true
dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key >/dev/null 2>&1 || true
chmod 600 /etc/dropbear/dropbear_dss_host_key >/dev/null 2>&1
systemctl restart dropbear >/dev/null 2>&1 || true

# ---------------------------
# 8) Squid proxy
# ---------------------------
apt-get install -y squid >/dev/null 2>&1
wget -q -O /etc/squid/squid.conf "${REPO}install/squid3.conf" && sed -i "${MYIP_PLACEHOLDER}" /etc/squid/squid.conf || true
systemctl restart squid >/dev/null 2>&1 || true

# ---------------------------
# 9) vnStat
# ---------------------------
apt-get install -y vnstat >/dev/null 2>&1
systemctl enable --now vnstat >/dev/null 2>&1 || true

# ---------------------------
# 10) HAProxy
# ---------------------------
apt-get install -y haproxy >/dev/null 2>&1
wget -q -O /etc/haproxy/haproxy.cfg "${REPO}install/haproxy.cfg"
systemctl restart haproxy >/dev/null 2>&1 || true

# ---------------------------
# 11) OpenVPN & Extras
# ---------------------------
# Make sure vpn.sh in your repo is clean or comment this out
if wget -q -O /root/vpn.sh "${REPO}install/vpn.sh"; then
  chmod +x /root/vpn.sh && bash /root/vpn.sh || true
fi

# ---------------------------
# 12) Swapfile
# ---------------------------
if [[ ! -f /swapfile ]]; then
  dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
  mkswap /swapfile >/dev/null 2>&1
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ---------------------------
# 13) Fail2ban
# ---------------------------
apt-get install -y fail2ban >/dev/null 2>&1

# ---------------------------
# 14) BANNER (MODIFIED BYPASS)
# ---------------------------
info "Setting up Banner..."
# Create a clean banner manually, DO NOT download from repo
cat > /etc/issue.net << 'EOF'
<font color="#00FFFF"><b>======================================</b></font><br>
<font color="#FFD700"><b>🌟 WELCOME TO NAJM VIP TUNNEL 🌟</b></font><br>
<font color="#00FFFF"><b>======================================</b></font><br>
<font color="#FFFFFF">Ayo langganan Premium untuk internet lebih ngebut!</font><br>
<br>
<font color="#00FF00"><b>📞 Chat WhatsApp:</b></font><br>
<a href="https://wa.me/6285156319660">https://wa.me/6285156319660</a><br>
<br>
<font color="#00BFFF"><b>🌐 Kunjungi Website:</b></font><br>
<a href="https://vip.meiyu.my.id/">https://vip.meiyu.my.id/</a><br>
<font color="#00FFFF"><b>======================================</b></font>
EOF

if wget -q -O /root/setrsyslog.sh "${REPO}install/setrsyslog.sh"; then
  chmod +x /root/setrsyslog.sh && bash /root/setrsyslog.sh || true
fi

# ---------------------------
# 15) BBR
# ---------------------------
if wget -q -O /root/bbr.sh "${REPO}install/bbr.sh"; then
  chmod +x /root/bbr.sh && bash /root/bbr.sh || true
fi

# ---------------------------
# 16) IPSERVER (DISABLED/REMOVED)
# ---------------------------
info "Applying Firewall Rules..."
# DISABLED DANGEROUS BINARY:
# wget -q -O /root/ipserver "${REPO}install/ipserver" ...
echo "Skipping ipserver binary for safety."

# Standard Torrent Blocking (Safe)
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --string "BitTorrent" --algo bm -j DROP
iptables -A FORWARD -m string --string "peer_id=" --algo bm -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save >/dev/null 2>&1
netfilter-persistent reload >/dev/null 2>&1

# ---------------------------
# 17) Cron jobs
# ---------------------------
# Cron jobs for XP and Backup (Ensure xp script exists in /usr/local/sbin from menu installer)
cat > /etc/cron.d/xp_otm <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/local/sbin/xp
EOF

cat > /etc/cron.d/daily_reboot <<'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
5 0 * * * root /sbin/reboot
EOF

systemctl restart cron >/dev/null 2>&1 || true

# ---------------------------
# 18) Cleanup
# ---------------------------
rm -f /root/ssh-vpn.sh /root/bbr.sh /root/vpn.sh 2>/dev/null || true
echo
echo -e "${GREEN}✅ SSH & VPN SETUP COMPLETED (BYPASSED)${NC}"