#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# setup-audit-pro.sh (Multi-Architecture Version)
# Debian 12 / Ubuntu
#
# Mendukung: KVM, VMware, LXC, Docker VM, Bare-metal
# ============================================================

# =========================
# KONFIGURASI
# =========================
TOKEN="8260557422:AAFmxRgYnNNrXXwi6JqM_tmaCq8Xq_Ls4D0" 
CHAT_ID="6663648335"

# Daftar service yang dipantau
SERVICES=("udp-custom" "xray" "openvpn" "dropbear" "haproxy" "nginx" "cron")

# Interval polling status service (detik)
CHECK_INTERVAL=5

# Nama file/rules/service
ENV_FILE="/etc/system-health-monitor.env"
MONITOR_BIN="/usr/local/bin/system-health-monitor.sh"
SYSTEMD_UNIT="/etc/systemd/system/system-health-monitor.service"
AUDIT_RULES_FILE="/etc/audit/rules.d/99-system-health-monitor.rules"
BASELINE_DIR="/var/lib/system-health-monitor/baseline"

# =========================
# VALIDASI & DETEKSI LINGKUNGAN
# =========================
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Jalankan script ini sebagai root."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: Script ini ditujukan untuk Debian/Ubuntu (apt-get)."
    exit 1
fi

if [[ -z "${TOKEN// }" || -z "${CHAT_ID// }" ]]; then
    echo "ERROR: TOKEN dan CHAT_ID wajib diisi."
    exit 1
fi

IS_CONTAINER=false
if command -v systemd-detect-virt >/dev/null 2>&1; then
    if systemd-detect-virt --container >/dev/null 2>&1; then
        IS_CONTAINER=true
        echo "==> [INFO] Lingkungan Container (LXC/Docker) terdeteksi. Mode: Basic."
    else
        echo "==> [INFO] Lingkungan VM/Bare-metal terdeteksi. Mode: Full Forensic."
    fi
else
    echo "==> [WARN] systemd-detect-virt tidak ditemukan, mengasumsikan lingkungan VM."
fi

# =========================
# UTILITAS
# =========================
log() {
    echo "==> $*"
}

join_by_space() {
    local IFS=' '
    echo "$*"
}

backup_file_if_exists() {
    local src="$1"
    local dst="$2"
    if [[ -e "$src" ]]; then
        cp -a "$src" "$dst"
    fi
}

# =========================
# INSTALL PAKET
# =========================
log "[1/8] Menginstal paket yang dibutuhkan..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

PKGS="inotify-tools curl jq e2fsprogs systemd rsyslog coreutils procps grep sed gawk findutils"
if [[ "$IS_CONTAINER" == "false" ]]; then
    PKGS="$PKGS auditd audispd-plugins"
fi

# shellcheck disable=SC2086
apt-get install -y $PKGS >/dev/null

# =========================
# AKTIFKAN JOURNAL PERSISTENT
# =========================
log "[2/8] Mengaktifkan persistent journald..."
mkdir -p /var/log/journal
if grep -qE '^\s*#?\s*Storage=' /etc/systemd/journald.conf; then
    sed -i 's/^\s*#\?\s*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
else
    printf '\nStorage=persistent\n' >> /etc/systemd/journald.conf
fi
systemctl restart systemd-journald
journalctl --flush || true

# =========================
# SIMPAN BASELINE
# =========================
log "[3/8] Menyimpan baseline konfigurasi awal..."
mkdir -p "$BASELINE_DIR"
chmod 700 "$BASELINE_DIR"

TS="$(date +%F_%H%M%S)"
mkdir -p "$BASELINE_DIR/$TS"

backup_file_if_exists "/etc/shadow" "$BASELINE_DIR/$TS/shadow"
if [[ -d /etc/ssh ]]; then
    mkdir -p "$BASELINE_DIR/$TS/ssh"
    cp -a /etc/ssh/. "$BASELINE_DIR/$TS/ssh/" 2>/dev/null || true
fi
if [[ -d /etc/systemd/system ]]; then
    mkdir -p "$BASELINE_DIR/$TS/systemd-system"
    cp -a /etc/systemd/system/. "$BASELINE_DIR/$TS/systemd-system/" 2>/dev/null || true
fi

# =========================
# ENV FILE
# =========================
log "[4/8] Menulis environment file monitor..."
cat > "$ENV_FILE" <<EOF
TOKEN='${TOKEN}'
CHAT_ID='${CHAT_ID}'
SERVICES='$(join_by_space "${SERVICES[@]}")'
CHECK_INTERVAL='${CHECK_INTERVAL}'
BASELINE_DIR='${BASELINE_DIR}'
UNIT_JOURNAL_LINES='40'
MGR_JOURNAL_LINES='40'
SINCE_WINDOW='-3 min'
IS_CONTAINER='${IS_CONTAINER}'
EOF
chmod 600 "$ENV_FILE"

# =========================
# AUDIT RULES PERSISTEN (KONDISIONAL)
# =========================
if [[ "$IS_CONTAINER" == "false" ]]; then
    log "[5/8] Memasang audit rules persisten (Mode KVM/VM)..."
    cat > "$AUDIT_RULES_FILE" <<'EOF'
# Service control tools
-a always,exit -F arch=b64 -F path=/usr/bin/systemctl -F perm=x -k svc_ctrl
-a always,exit -F arch=b64 -F path=/usr/sbin/service -F perm=x -k svc_ctrl
-a always,exit -F arch=b64 -F path=/usr/bin/systemd-run -F perm=x -k svc_ctrl
-a always,exit -F arch=b64 -F path=/usr/bin/busctl -F perm=x -k svc_ctrl
-a always,exit -F arch=b64 -F path=/usr/bin/loginctl -F perm=x -k svc_ctrl

# Direct signal tools
-a always,exit -F arch=b64 -F path=/usr/bin/kill -F perm=x -k svc_kill
-a always,exit -F arch=b64 -F path=/usr/bin/pkill -F perm=x -k svc_kill
-a always,exit -F arch=b64 -F path=/usr/bin/killall -F perm=x -k svc_kill

# Host power paths
-a always,exit -F arch=b64 -F path=/usr/sbin/shutdown -F perm=x -k host_power
-a always,exit -F arch=b64 -F path=/usr/sbin/reboot -F perm=x -k host_power
-a always,exit -F arch=b64 -F path=/usr/sbin/poweroff -F perm=x -k host_power

# Cron execution / changes
-a always,exit -F arch=b64 -F path=/usr/bin/crontab -F perm=x -k cron_exec
-a always,exit -F arch=b64 -F path=/etc/crontab -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/etc/cron.d/ -F perm=wa -k cron_changed

# systemd unit changes
-a always,exit -F arch=b64 -F dir=/etc/systemd/system/ -F perm=wa -k unit_changed
-a always,exit -F arch=b64 -F dir=/lib/systemd/system/ -F perm=wa -k unit_changed

# Password / SSH config changes
-a always,exit -F arch=b64 -F path=/etc/shadow -F perm=wa -k password_changed
-a always,exit -F arch=b64 -F dir=/etc/ssh/ -F perm=wa -k ssh_config_changed
EOF

    TMP_RULES="$(mktemp)"
    while IFS= read -r line; do
        if [[ "$line" =~ path=([^[:space:]]+) ]]; then
            if [[ -e "${BASH_REMATCH[1]}" ]]; then echo "$line" >> "$TMP_RULES"; fi
        elif [[ "$line" =~ dir=([^[:space:]]+) ]]; then
            if [[ -d "${BASH_REMATCH[1]}" ]]; then echo "$line" >> "$TMP_RULES"; fi
        else
            echo "$line" >> "$TMP_RULES"
        fi
    done < "$AUDIT_RULES_FILE"
    mv "$TMP_RULES" "$AUDIT_RULES_FILE"
    chmod 640 "$AUDIT_RULES_FILE"

    systemctl enable auditd >/dev/null 2>&1 || true
    if ! augenrules --load; then
        echo "WARN: augenrules --load gagal (mungkin kernel tidak mendukung). Melanjutkan..."
    fi
    systemctl restart auditd || true
else
    log "[5/8] Mode Container terdeteksi. Melewati konfigurasi auditd..."
    systemctl disable --now auditd.service >/dev/null 2>&1 || true
    rm -f "$AUDIT_RULES_FILE"
fi

# =========================
# MONITOR SCRIPT
# =========================
log "[6/8] Membuat script monitor daemon..."
cat > "$MONITOR_BIN" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/system-health-monitor.env"
[[ -r "$ENV_FILE" ]] || { echo "ENV file tidak ditemukan"; exit 1; }
source "$ENV_FILE"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
read -r -a SERVICES_ARR <<< "${SERVICES:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
UNIT_JOURNAL_LINES="${UNIT_JOURNAL_LINES:-40}"
MGR_JOURNAL_LINES="${MGR_JOURNAL_LINES:-40}"

send_tg_raw() {
    local text="$1"
    jq -Rn \
        --arg chat_id "$CHAT_ID" \
        --arg text "$text" \
        '{chat_id:$chat_id, text:$text, disable_web_page_preview:true}' \
    | curl -fsS -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -H "Content-Type: application/json" -d @- >/dev/null
}

send_tg() {
    local text="$1"
    local max=3500
    local chunk split_at

    while [[ -n "$text" ]]; do
        if (( ${#text} <= max )); then
            send_tg_raw "$text"
            break
        fi
        split_at=$(awk -v s="$text" -v m="$max" 'BEGIN{p=m; while (p>1 && substr(s,p,1)!="\n") p--; if (p<=1) p=m; print p}')
        chunk="${text:0:split_at}"
        send_tg_raw "$chunk"
        text="${text:split_at}"
    done
}

safe_cmd() { "$@" 2>/dev/null || true; }
escape_regex() { printf '%s' "$1" | sed 's/[][(){}.^$*+?|\/]/\\&/g'; }
unit_exists() { systemctl show "$1" -p Id >/dev/null 2>&1; }

get_unit_props() {
    safe_cmd systemctl show "$1" -p Id -p LoadState -p ActiveState -p SubState -p Result -p MainPID -p ExecMainPID -p ExecMainCode -p ExecMainStatus
}

recent_unit_journal() {
    safe_cmd journalctl -u "$1" --since "$SINCE_WINDOW" --no-pager -o short-iso | tail -n "$UNIT_JOURNAL_LINES"
}

recent_manager_journal() {
    local unit_rx; unit_rx="$(escape_regex "$1")"
    safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso \
        | grep -Ei "systemd\\[1\\]|\\bCRON\\b|${unit_rx}|shutdown|Stopping|Stopped|Failed" \
        | tail -n "$MGR_JOURNAL_LINES"
}

recent_audit_by_key() {
    if [[ "$IS_CONTAINER" == "true" ]]; then return 0; fi
    safe_cmd ausearch -k "$1" -ts recent -i | tail -n 100
}

filter_audit_for_unit() {
    if [[ "$IS_CONTAINER" == "true" ]]; then return 0; fi
    local text="$1"; local unit_rx; unit_rx="$(escape_regex "$2")"
    printf '%s\n' "$text" | grep -Ei "${unit_rx}|systemctl|kill|pkill|shutdown" | tail -n 40 || true
}

trim_block() {
    local text="$1"; local max_lines="${2:-25}"
    if [[ -z "$(echo "$text" | tr -d '[:space:]')" ]]; then
        echo "-"
    else
        printf '%s\n' "$text" | tail -n "$max_lines"
    fi
}

password_change_report() {
    local audit_shadow shelllog msg
    shelllog="$(safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso | grep -Ei 'passwd|shadow|chpasswd|usermod|sudo|su:' | tail -n 30)"
    
    if [[ "$IS_CONTAINER" == "false" ]]; then
        audit_shadow="[Audit - password_changed]
$(trim_block "$(recent_audit_by_key password_changed)" 30)"
    else
        audit_shadow="[Audit Log]
Tidak tersedia (Mode Container)"
    fi

    msg=$(cat <<MSG
🚨 ALERT: /etc/shadow BERUBAH

Host  : ${HOSTNAME_FQDN}
Waktu : $(date '+%F %T %Z')

${audit_shadow}

[Journal terkait]
$(trim_block "$shelllog" 30)
MSG
)
    send_tg "$msg"
}

ssh_change_report() {
    local ssh_test sshlog msg audit_ssh
    ssh_test="$(safe_cmd sshd -t 2>&1)"
    sshlog="$(safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso | grep -Ei 'sshd|sshd_config|ssh' | tail -n 30)"

    if [[ "$IS_CONTAINER" == "false" ]]; then
        audit_ssh="[Audit - ssh_config_changed]
$(trim_block "$(recent_audit_by_key ssh_config_changed)" 35)"
    else
        audit_ssh="[Audit Log]
Tidak tersedia (Mode Container)"
    fi

    msg=$(cat <<MSG
🚨 ALERT: KONFIGURASI SSH BERUBAH

Host  : ${HOSTNAME_FQDN}
Validasi sshd: $( [[ -n "$ssh_test" ]] && echo "ERROR" || echo "OK" )

${audit_ssh}

[sshd -t output]
${ssh_test:-Tidak ada error syntax.}

[Journal terkait]
$(trim_block "$sshlog" 30)
MSG
)
    send_tg "$msg"
}

service_stop_report() {
    local unit="$1"
    sleep 1

    local props unitlog managerlog msg audit_block
    props="$(get_unit_props "$unit")"
    unitlog="$(recent_unit_journal "$unit")"
    managerlog="$(recent_manager_journal "$unit")"

    if [[ "$IS_CONTAINER" == "false" ]]; then
        local audit_ctrl="$(recent_audit_by_key svc_ctrl)"
        local audit_kill="$(recent_audit_by_key svc_kill)"
        audit_block="[Audit - Service Control]
$(trim_block "$(filter_audit_for_unit "$audit_ctrl" "$unit")" 20)

[Audit - Kill Signals]
$(trim_block "$(filter_audit_for_unit "$audit_kill" "$unit")" 15)"
    else
        audit_block="[Audit Log]
Dinonaktifkan pada Container/LXC."
    fi

    msg=$(cat <<MSG
⚠️ ALERT: SERVICE BERHENTI

Host   : ${HOSTNAME_FQDN}
Unit   : ${unit}
Waktu  : $(date '+%F %T %Z')

[systemctl show]
$(trim_block "$props" 15)

${audit_block}

[Journal unit]
$(trim_block "$unitlog" 20)

[Journal manager]
$(trim_block "$managerlog" 20)
MSG
)
    send_tg "$msg"
}

monitor_services() {
    declare -A STATE=()
    for s in "${SERVICES_ARR[@]}"; do
        STATE["$s"]="$(unit_exists "$s" && safe_cmd systemctl is-active "$s" || echo "missing")"
    done

    while true; do
        sleep "$CHECK_INTERVAL"
        for s in "${SERVICES_ARR[@]}"; do
            local current="$(unit_exists "$s" && safe_cmd systemctl is-active "$s" || echo "missing")"
            if [[ "${STATE[$s]}" == "active" && "$current" != "active" ]]; then
                service_stop_report "$s"
            fi
            STATE["$s"]="$current"
        done
    done
}

monitor_files() {
    local watch_paths=()
    [[ -e /etc/shadow ]] && watch_paths+=("/etc/shadow")
    [[ -d /etc/ssh ]] && watch_paths+=("/etc/ssh")

    if [[ ${#watch_paths[@]} -eq 0 ]]; then return 0; fi

    inotifywait -m -r -e modify,attrib,close_write,moved_to,create,delete,move \
        --format '%w|%e|%f' "${watch_paths[@]}" 2>/dev/null |
    while IFS='|' read -r directory events filename; do
        local filepath="${directory}${filename}"
        sleep 1
        if [[ "$filepath" == "/etc/shadow" || "$filepath" == *"/shadow" ]]; then
            password_change_report
        fi
        if [[ "$filepath" == *"/sshd_config"* || "$filepath" == *"/ssh/"* ]]; then
            ssh_change_report
        fi
    done
}

main() {
    local s_txt="$(printf '%s, ' "${SERVICES_ARR[@]}" | sed 's/, $//')"
    local mode_txt="KVM/VM (Forensic Audit + Journal)"
    [[ "$IS_CONTAINER" == "true" ]] && mode_txt="Container (Journal + INotify)"
    
    send_tg "🛡️ System Health Monitor aktif di ${HOSTNAME_FQDN}\n\nLayanan: ${s_txt}\nMode: ${mode_txt}"
    
    monitor_services &
    monitor_files &
    wait
}

main
EOF
chmod 700 "$MONITOR_BIN"

# =========================
# SYSTEMD SERVICE
# =========================
log "[7/8] Membuat service systemd monitor..."
cat > "$SYSTEMD_UNIT" <<'EOF'
[Unit]
Description=System Health Monitor (Forensic + Telegram)
After=network-online.target systemd-journald.service
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/local/bin/system-health-monitor.sh
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

# =========================
# ENABLE & START
# =========================
log "[8/8] Mengaktifkan monitor..."
systemctl daemon-reload
systemctl enable system-health-monitor.service >/dev/null
systemctl restart system-health-monitor.service

echo
echo "============================================================"
echo "SELESAI"
echo "============================================================"
echo "Script berhasil mendeteksi arsitektur dan menyesuaikan mode operasi."
echo "Mode Saat Ini: $( [[ "$IS_CONTAINER" == "true" ]] && echo "Container (LXC/Docker)" || echo "Full VM (KVM/Bare-metal)" )"
echo "Monitor aktif sebagai: system-health-monitor.service"
echo "============================================================"