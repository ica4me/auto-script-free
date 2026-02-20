#!/bin/bash
rm -- "$0"
systemctl stop ws
curl -sS ipv4.icanhazip.com > /usr/bin/.ipvps
REPO="https://raw.githubusercontent.com/ica4me/auto-script-free/main/"
wget -O /usr/bin/ws "${REPO}udp-custom/ws"
wget -O /usr/bin/config.conf "${REPO}udp-custom/config.conf"
wget -O /etc/systemd/system/ws.service "${REPO}udp-custom/ws.service"
chmod +x /usr/bin/ws
systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service