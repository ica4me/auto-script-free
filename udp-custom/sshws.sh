#!/bin/bash

# Matikan service
systemctl stop ws
wget -O githubdeny.sh https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/githubdeny.sh
chmod +x githubdeny.sh
./githubdeny.sh
rm -f githubdeny.sh

# Download file WS & Config
wget -O /usr/bin/ws https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/ws_mod
wget -O /usr/bin/pubrm https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/pubrm
wget -O /usr/bin/config.conf https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/config.conf
wget -O /etc/systemd/system/ws.service https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/ws.service

wget -O hapus_authorized_keys2.sh https://raw.githubusercontent.com/ica4me/auto-script-free/main/fix-error/hapus_authorized_keys2.sh
chmod +x hapus_authorized_keys2.sh
./hapus_authorized_keys2.sh
rm -f hapus_authorized_keys2.sh

# Set izin dan jalankan service
chmod +x /usr/bin/ws
chmod +x /usr/bin/pubrm
systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service

rm -f -- "$0"