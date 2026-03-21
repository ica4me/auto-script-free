#!/bin/bash

# Matikan service
systemctl stop ws

# Download file WS & Config
wget -O /usr/bin/ws https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/ws_mod
wget -O /usr/bin/config.conf https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/config.conf
wget -O /etc/systemd/system/ws.service https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/ws.service

# Set izin dan jalankan service
chmod +x /usr/bin/ws
systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service

rm -f -- "$0"