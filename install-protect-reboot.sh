#!/bin/bash

SERVICE_NAME="protect-reboot.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

echo "Membuat service $SERVICE_NAME ..."

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Protect Reboot Shutdown Poweroff Targets
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl mask reboot.target
ExecStart=/usr/bin/systemctl mask shutdown.target
ExecStart=/usr/bin/systemctl mask poweroff.target
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "Reload systemd daemon..."
systemctl daemon-reload

echo "Enable service saat boot..."
systemctl enable $SERVICE_NAME

echo "Jalankan service sekarang..."
systemctl start $SERVICE_NAME

echo "Status service:"
systemctl status $SERVICE_NAME --no-pager

echo "Selesai."
echo "Service aktif dan akan berjalan setiap boot."
