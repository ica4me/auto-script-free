#!/bin/bash
set -e

SERVICE_NAME="ssh-guardian"
SCRIPT_PATH="/usr/local/bin/ssh-guardian.sh"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

echo "Installing SSH Guardian..."

# ================= TELEGRAM CONFIG =================
BOT_KEY=$(grep -E "^#bot# " /etc/bot/.bot.db 2>/dev/null | awk '{print $2}')
CHAT_ID=$(grep -E "^#bot# " /etc/bot/.bot.db 2>/dev/null | awk '{print $3}')
API_URL="https://api.telegram.org/bot${BOT_KEY}/sendMessage"

# ================= MONITOR SCRIPT =================
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

BOT_KEY=$(grep -E "^#bot# " /etc/bot/.bot.db 2>/dev/null | awk '{print $2}')
CHAT_ID=$(grep -E "^#bot# " /etc/bot/.bot.db 2>/dev/null | awk '{print $3}')
API_URL="https://api.telegram.org/bot${BOT_KEY}/sendMessage"

notify_fail() {
    [ -z "$BOT_KEY" ] && exit 0
    [ -z "$CHAT_ID" ] && exit 0
    curl -s --max-time 10 \
    -d "chat_id=$CHAT_ID&text=❌ SSH SERVICE FAILED TO RESTART on $(hostname)" \
    "$API_URL" >/dev/null 2>&1
}

check_and_fix() {
    for svc in ssh sshd; do
        if systemctl list-unit-files | grep -q "^${svc}.service"; then
            if ! systemctl is-active --quiet "$svc"; then
                systemctl restart "$svc" >/dev/null 2>&1
                sleep 2
                if ! systemctl is-active --quiet "$svc"; then
                    notify_fail
                fi
            fi
        fi
    done
}

while true; do
    check_and_fix
    sleep 10
done
EOF

chmod +x "$SCRIPT_PATH"

# ================= SYSTEMD SERVICE =================
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=SSH Guardian Monitor
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
Nice=10

[Install]
WantedBy=multi-user.target
EOF

# ================= ENABLE SERVICE =================
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo "SSH Guardian installed & running"
echo "Check status: systemctl status $SERVICE_NAME"