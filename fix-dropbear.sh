#!/bin/bash
# ==========================================
# Fix Dropbear Port 109 & 143 | Auto Script
# ==========================================
clear
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[INFO] Stopping Dropbear Service...${NC}"
systemctl stop dropbear

echo -e "${GREEN}[INFO] Overwriting Configuration (/etc/default/dropbear)...${NC}"
cat > /etc/default/dropbear <<END
# Disabled configuration option
NO_START=0

# Default port (109)
DROPBEAR_PORT=109

# Extra ports (143)
DROPBEAR_EXTRA_ARGS="-p 143"

# Banner (Optional)
DROPBEAR_BANNER="/etc/issue.net"

# Key Locations
DROPBEAR_RSAKEY_DIR="/etc/dropbear"
DROPBEAR_DSSKEY_DIR="/etc/dropbear"
DROPBEAR_ECDSAKEY_DIR="/etc/dropbear"
END

echo -e "${GREEN}[INFO] Restarting Dropbear Service...${NC}"
systemctl daemon-reload
systemctl restart dropbear

echo -e "${GREEN}[INFO] Checking Active Ports...${NC}"
sleep 1
netstat -tulpn | grep dropbear

if systemctl is-active --quiet dropbear; then
    echo -e "\n${GREEN}[SUCCESS] Dropbear is RUNNING on Port 109 & 143${NC}"
else
    echo -e "\n${RED}[FAILED] Dropbear failed to start. Check logs.${NC}"
fi