#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# setup-audit-pro.sh
# Debian 12 / Ubuntu
#
# Mode otomatis:
# - KVM/bare metal/systemd + audit tersedia -> FULL FORENSIC
# - LXC/container + systemd               -> JOURNAL MODE
# - Docker/container tanpa systemd        -> PROCESS MODE
#
# Tujuan:
# - Kirim alert Telegram saat service/proses berhenti
# - Sertakan bukti runtime dari systemd/journal bila tersedia
# - Pakai auditd hanya jika benar-benar didukung environment
# ============================================================

# =========================
# KONFIGURASI
# =========================
TOKEN="GANTI_TOKEN_BARU"
CHAT_ID="GANTI_CHAT_ID"

# Nama target yang dipantau.
# Pada mode systemd: dianggap nama unit service
# Pada mode proc   : dianggap nama proses (pgrep)
TARGETS=("udp-custom" "xray" "openvpn" "dropbear" "haproxy" "nginx" "cron")

CHECK_INTERVAL=5
SINCE_WINDOW='-3 min'
UNIT_JOURNAL_LINES=40
MGR_JOURNAL_LINES=40

ENV_FILE="/etc/system-health-monitor.env"
MONITOR_BIN="/usr/local/bin/system-health-monitor.sh"
SYSTEMD_UNIT="/etc/systemd/system/system-health-monitor.service"
AUDIT_RULES_FILE="/etc/audit/rules.d/99-system-health-monitor.rules"
BASELINE_DIR="/var/lib/system-health-monitor/baseline"
RUN_LOG="/var/log/system-health-monitor.log"

# =========================
# VALIDASI
# =========================
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Jalankan script ini sebagai root."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: Script ini ditujukan untuk Debian/Ubuntu."
    exit 1
fi

if [[ -z "${TOKEN// }" || -z "${CHAT_ID// }" ]]; then
    echo "ERROR: TOKEN dan CHAT_ID wajib diisi."
    exit 1
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

safe_systemctl() {
    systemctl "$@" >/dev/null 2>&1 || true
}

# =========================
# DETEKSI ENVIRONMENT
# =========================
detect_virtualization() {
    local vt="unknown"

    if command -v systemd-detect-virt >/dev/null 2>&1; then
        vt="$(systemd-detect-virt 2>/dev/null || true)"
        [[ -z "$vt" ]] && vt="none"
    fi

    echo "$vt"
}

has_systemd_runtime() {
    command -v systemctl >/dev/null 2>&1 \
    && [[ -d /run/systemd/system ]] \
    && [[ "$(ps -p 1 -o comm= 2>/dev/null || true)" == "systemd" ]]
}

VIRT_TYPE="$(detect_virtualization)"
HAS_SYSTEMD=0
IS_CONTAINER=0
IS_VM=0

if has_systemd_runtime; then
    HAS_SYSTEMD=1
fi

if command -v systemd-detect-virt >/dev/null 2>&1; then
    systemd-detect-virt --quiet --container 2>/dev/null && IS_CONTAINER=1 || true
    systemd-detect-virt --quiet --vm 2>/dev/null && IS_VM=1 || true
fi

# =========================
# INSTALL PAKET DASAR
# =========================
log "[1/9] Menginstal paket dasar..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y \
    curl jq inotify-tools e2fsprogs \
    coreutils procps psmisc grep sed gawk findutils >/dev/null

# =========================
# MODE
# =========================
MONITOR_MODE="proc"
AUDIT_AVAILABLE=0

if [[ "$HAS_SYSTEMD" -eq 1 ]]; then
    MONITOR_MODE="systemd-journal"
fi

# =========================
# JOURNAL PERSISTENT (jika systemd)
# =========================
log "[2/9] Menyiapkan logging..."
if [[ "$HAS_SYSTEMD" -eq 1 ]]; then
    mkdir -p /var/log/journal
    if [[ -f /etc/systemd/journald.conf ]]; then
        if grep -qE '^\s*#?\s*Storage=' /etc/systemd/journald.conf; then
            sed -i 's/^\s*#\?\s*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
        else
            printf '\nStorage=persistent\n' >> /etc/systemd/journald.conf
        fi
    fi
    safe_systemctl restart systemd-journald
    journalctl --flush >/dev/null 2>&1 || true
else
    touch "$RUN_LOG"
fi

# =========================
# BASELINE
# =========================
log "[3/9] Menyimpan baseline konfigurasi..."
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
# AUDIT MODE (hanya VM/bare metal + systemd)
# =========================
log "[4/9] Menentukan dukungan audit..."
if [[ "$HAS_SYSTEMD" -eq 1 && "$IS_CONTAINER" -eq 0 ]]; then
    apt-get install -y auditd audispd-plugins >/dev/null || true

    if command -v auditctl >/dev/null 2>&1 && command -v augenrules >/dev/null 2>&1; then
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
-a always,exit -F arch=b64 -F path=/usr/sbin/halt -F perm=x -k host_power
-a always,exit -F arch=b64 -F path=/usr/bin/shutdown -F perm=x -k host_power
-a always,exit -F arch=b64 -F path=/usr/bin/reboot -F perm=x -k host_power
-a always,exit -F arch=b64 -F path=/usr/bin/poweroff -F perm=x -k host_power
-a always,exit -F arch=b64 -F path=/usr/bin/halt -F perm=x -k host_power

# Cron execution / cron changes
-a always,exit -F arch=b64 -F path=/usr/bin/crontab -F perm=x -k cron_exec
-a always,exit -F arch=b64 -F path=/etc/crontab -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/etc/cron.d/ -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/etc/cron.daily/ -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/etc/cron.hourly/ -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/etc/cron.weekly/ -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/etc/cron.monthly/ -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/var/spool/cron/ -F perm=wa -k cron_changed
-a always,exit -F arch=b64 -F dir=/var/spool/cron/crontabs/ -F perm=wa -k cron_changed

# systemd unit/drop-in changes
-a always,exit -F arch=b64 -F dir=/etc/systemd/system/ -F perm=wa -k unit_changed
-a always,exit -F arch=b64 -F dir=/run/systemd/system/ -F perm=wa -k unit_changed
-a always,exit -F arch=b64 -F dir=/usr/lib/systemd/system/ -F perm=wa -k unit_changed
-a always,exit -F arch=b64 -F dir=/lib/systemd/system/ -F perm=wa -k unit_changed

# Password / SSH config changes
-a always,exit -F arch=b64 -F path=/etc/shadow -F perm=wa -k password_changed
-a always,exit -F arch=b64 -F dir=/etc/ssh/ -F perm=wa -k ssh_config_changed
EOF

        # buang rule yang path/dir-nya tidak ada
        TMP_RULES="$(mktemp)"
        while IFS= read -r line; do
            if [[ "$line" =~ path=([^[:space:]]+) ]]; then
                p="${BASH_REMATCH[1]}"
                [[ -e "$p" ]] && echo "$line" >> "$TMP_RULES"
            elif [[ "$line" =~ dir=([^[:space:]]+) ]]; then
                d="${BASH_REMATCH[1]}"
                [[ -d "$d" ]] && echo "$line" >> "$TMP_RULES"
            else
                echo "$line" >> "$TMP_RULES"
            fi
        done < "$AUDIT_RULES_FILE"
        mv "$TMP_RULES" "$AUDIT_RULES_FILE"
        chmod 640 "$AUDIT_RULES_FILE"

        safe_systemctl enable auditd

        augenrules --load >/dev/null 2>&1 || true
        safe_systemctl restart auditd

        if auditctl -s >/dev/null 2>&1; then
            AUDIT_AVAILABLE=1
            MONITOR_MODE="systemd-audit"
        else
            AUDIT_AVAILABLE=0
            MONITOR_MODE="systemd-journal"
        fi
    fi
fi

# =========================
# ENV FILE
# =========================
log "[5/9] Menulis environment file..."
cat > "$ENV_FILE" <<EOF
TOKEN='${TOKEN}'
CHAT_ID='${CHAT_ID}'
TARGETS='$(join_by_space "${TARGETS[@]}")'
CHECK_INTERVAL='${CHECK_INTERVAL}'
SINCE_WINDOW='${SINCE_WINDOW}'
UNIT_JOURNAL_LINES='${UNIT_JOURNAL_LINES}'
MGR_JOURNAL_LINES='${MGR_JOURNAL_LINES}'
BASELINE_DIR='${BASELINE_DIR}'
RUN_LOG='${RUN_LOG}'
VIRT_TYPE='${VIRT_TYPE}'
HAS_SYSTEMD='${HAS_SYSTEMD}'
IS_CONTAINER='${IS_CONTAINER}'
IS_VM='${IS_VM}'
AUDIT_AVAILABLE='${AUDIT_AVAILABLE}'
MONITOR_MODE='${MONITOR_MODE}'
EOF
chmod 600 "$ENV_FILE"

# =========================
# MONITOR BIN
# =========================
log "[6/9] Membuat monitor..."
cat > "$MONITOR_BIN" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/system-health-monitor.env"
[[ -r "$ENV_FILE" ]] || { echo "ENV file tidak ditemukan: $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
read -r -a TARGETS_ARR <<< "${TARGETS:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
UNIT_JOURNAL_LINES="${UNIT_JOURNAL_LINES:-40}"
MGR_JOURNAL_LINES="${MGR_JOURNAL_LINES:-40}"
SINCE_WINDOW="${SINCE_WINDOW:--3 min}"
RUN_LOG="${RUN_LOG:-/var/log/system-health-monitor.log}"

send_tg_raw() {
    local text="$1"
    jq -Rn \
        --arg chat_id "$CHAT_ID" \
        --arg text "$text" \
        '{chat_id:$chat_id, text:$text, disable_web_page_preview:true}' \
    | curl -fsS -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d @- >/dev/null
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

        split_at=$(awk -v s="$text" -v m="$max" 'BEGIN{
            p=m
            while (p>1 && substr(s,p,1)!="\n") p--
            if (p<=1) p=m
            print p
        }')
        chunk="${text:0:split_at}"
        send_tg_raw "$chunk"
        text="${text:split_at}"
    done
}

safe_cmd() {
    "$@" 2>/dev/null || true
}

escape_regex() {
    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\/]/\\&/g'
}

trim_block() {
    local text="$1"
    local max_lines="${2:-25}"
    printf '%s\n' "$text" | tail -n "$max_lines"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

unit_exists() {
    [[ "${HAS_SYSTEMD:-0}" == "1" ]] || return 1
    systemctl show "$1" -p Id >/dev/null 2>&1
}

get_unit_props() {
    local unit="$1"
    safe_cmd systemctl show "$unit" \
        -p Id \
        -p Names \
        -p LoadState \
        -p ActiveState \
        -p SubState \
        -p Result \
        -p MainPID \
        -p ExecMainPID \
        -p ExecMainCode \
        -p ExecMainStatus \
        -p ExecMainStartTimestamp \
        -p ExecMainExitTimestamp \
        -p StateChangeTimestamp \
        -p ActiveEnterTimestamp \
        -p ActiveExitTimestamp \
        -p InactiveEnterTimestamp \
        -p FragmentPath \
        -p UnitFileState \
        -p InvocationID
}

recent_unit_journal() {
    local unit="$1"
    [[ "${HAS_SYSTEMD:-0}" == "1" ]] || return 0
    safe_cmd journalctl -u "$unit" --since "$SINCE_WINDOW" --no-pager -o short-iso | tail -n "$UNIT_JOURNAL_LINES"
}

recent_manager_journal() {
    local unit="$1"
    local unit_rx
    unit_rx="$(escape_regex "$unit")"

    if has_cmd journalctl; then
        safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso \
            | grep -Ei "systemd\\[1\\]|\\bCRON\\b|cron\\[[0-9]+\\]|${unit_rx}|shutdown|reboot|poweroff|halt|Stopping|Stopped|Starting|Failed" \
            | tail -n "$MGR_JOURNAL_LINES"
    elif [[ -f /var/log/syslog ]]; then
        grep -Ei "${unit_rx}|CRON|cron|shutdown|reboot|poweroff|halt" /var/log/syslog | tail -n "$MGR_JOURNAL_LINES" || true
    else
        return 0
    fi
}

recent_audit_by_key() {
    local key="$1"
    [[ "${AUDIT_AVAILABLE:-0}" == "1" ]] || return 0
    has_cmd ausearch || return 0
    safe_cmd ausearch -k "$key" -ts recent -i | tail -n 100
}

filter_audit_for_target() {
    local text="$1"
    local target="$2"
    local rx
    rx="$(escape_regex "$target")"
    printf '%s\n' "$text" \
        | grep -Ei "${rx}|systemctl|service|systemd-run|busctl|loginctl|kill|pkill|killall|shutdown|reboot|poweroff|halt|CRON|cron" \
        | tail -n 40 || true
}

guess_cause_systemd() {
    local unit="$1"
    local props="$2"
    local audit_ctrl="$3"
    local audit_kill="$4"
    local audit_power="$5"
    local audit_cron="$6"
    local audit_cronchg="$7"
    local audit_unitchg="$8"
    local managerlog="$9"

    local unit_rx
    unit_rx="$(escape_regex "$unit")"

    if grep -qiE "shutdown|reboot|poweroff|halt" <<< "$audit_power"$'\n'"$managerlog"; then
        echo "Kemungkinan besar unit berhenti karena host sedang shutdown/reboot/poweroff."
        return 0
    fi

    if grep -qiE "\\bCRON\\b|cron\\[[0-9]+\\]" <<< "$managerlog"; then
        if grep -qiE "systemctl|service|systemd-run" <<< "$audit_ctrl"$'\n'"$audit_cron"; then
            echo "Sangat mungkin dipicu oleh CRON yang menjalankan kontrol service."
        else
            echo "Ada indikasi kuat dipicu job CRON dari journal."
        fi
        return 0
    fi

    if grep -qiE "(a1=stop|a1=restart|a1=try-restart|a1=reload-or-restart|a1=kill|a1=disable|a1=mask)" <<< "$audit_ctrl" && \
       grep -qiE "$unit_rx|${unit_rx}\.service" <<< "$audit_ctrl"$'\n'"$managerlog"; then
        echo "Terlihat jejak perintah kontrol service yang menargetkan unit ini."
        return 0
    fi

    if grep -qiE "kill|pkill|killall" <<< "$audit_kill"; then
        if grep -q '^Result=signal$' <<< "$props"; then
            echo "Kemungkinan besar proses unit dihentikan oleh sinyal kill/pkill/killall."
        else
            echo "Ada jejak perintah kill/pkill/killall di jendela waktu yang sama."
        fi
        return 0
    fi

    if grep -q '^Result=exit-code$' <<< "$props"; then
        echo "Main process unit keluar sendiri atau crash dengan exit code non-zero."
        return 0
    fi

    if grep -q '^Result=signal$' <<< "$props"; then
        echo "Main process unit berakhir oleh sinyal."
        return 0
    fi

    if grep -q '^Result=timeout$' <<< "$props"; then
        echo "Unit berhenti karena timeout."
        return 0
    fi

    if grep -qiE "Failed|Stopped" <<< "$managerlog" && [[ -n "$audit_unitchg" ]]; then
        echo "Ada perubahan unit/drop-in systemd di sekitar waktu kejadian."
        return 0
    fi

    if [[ -n "$audit_cronchg" ]]; then
        echo "Ada perubahan konfigurasi cron di sekitar waktu kejadian."
        return 0
    fi

    echo "Penyebab belum 100% konklusif; lihat bukti di bawah."
}

guess_cause_proc() {
    local name="$1"
    local ctx="$2"

    if grep -qiE "\\bCRON\\b|cron\\[[0-9]+\\]" <<< "$ctx"; then
        echo "Ada indikasi proses terpengaruh job CRON dari log yang tersedia."
        return 0
    fi

    if grep -qiE "shutdown|reboot|poweroff|halt" <<< "$ctx"; then
        echo "Kemungkinan proses berhenti saat host/container shutdown."
        return 0
    fi

    echo "Mode process-only: penyebab tidak bisa dipastikan dari dalam container tanpa systemd/audit host."
}

password_change_report() {
    local audit_shadow shelllog
    audit_shadow="$(recent_audit_by_key password_changed)"

    if has_cmd journalctl; then
        shelllog="$(safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso | grep -Ei 'passwd|shadow|chpasswd|usermod|sudo|su:' | tail -n 30)"
    elif [[ -f /var/log/auth.log ]]; then
        shelllog="$(grep -Ei 'passwd|shadow|chpasswd|usermod|sudo|su:' /var/log/auth.log | tail -n 30 || true)"
    else
        shelllog=""
    fi

    local msg
    msg=$(
cat <<MSG
🚨 ALERT: /etc/shadow BERUBAH

Host  : ${HOSTNAME_FQDN}
Waktu : $(date '+%F %T %Z')
Mode  : ${MONITOR_MODE}

[Audit - password_changed]
$(trim_block "$audit_shadow" 30)

[Log terkait]
$(trim_block "$shelllog" 30)
MSG
)
    send_tg "$msg"
}

ssh_change_report() {
    local audit_ssh ssh_test sshlog
    audit_ssh="$(recent_audit_by_key ssh_config_changed)"
    ssh_test="$(safe_cmd sshd -t 2>&1)"

    if has_cmd journalctl; then
        sshlog="$(safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso | grep -Ei 'sshd|sshd_config|ssh' | tail -n 30)"
    elif [[ -f /var/log/auth.log ]]; then
        sshlog="$(grep -Ei 'sshd|sshd_config|ssh' /var/log/auth.log | tail -n 30 || true)"
    else
        sshlog=""
    fi

    local syntax_status="OK"
    [[ -n "$ssh_test" ]] && syntax_status="ERROR"

    local msg
    msg=$(
cat <<MSG
🚨 ALERT: KONFIGURASI SSH BERUBAH

Host         : ${HOSTNAME_FQDN}
Waktu        : $(date '+%F %T %Z')
Mode         : ${MONITOR_MODE}
Validasi sshd: ${syntax_status}

[Audit - ssh_config_changed]
$(trim_block "$audit_ssh" 35)

[sshd -t output]
${ssh_test:-Tidak ada output; syntax tampak valid.}

[Log terkait]
$(trim_block "$sshlog" 30)
MSG
)
    send_tg "$msg"
}

service_stop_report_systemd() {
    local unit="$1"
    sleep 1

    local props unitlog managerlog
    local audit_ctrl audit_kill audit_power audit_cron audit_cronchg audit_unitchg
    local cause

    props="$(get_unit_props "$unit")"
    unitlog="$(recent_unit_journal "$unit")"
    managerlog="$(recent_manager_journal "$unit")"

    audit_ctrl="$(recent_audit_by_key svc_ctrl)"
    audit_kill="$(recent_audit_by_key svc_kill)"
    audit_power="$(recent_audit_by_key host_power)"
    audit_cron="$(recent_audit_by_key cron_exec)"
    audit_cronchg="$(recent_audit_by_key cron_changed)"
    audit_unitchg="$(recent_audit_by_key unit_changed)"

    cause="$(guess_cause_systemd "$unit" "$props" "$audit_ctrl" "$audit_kill" "$audit_power" "$audit_cron" "$audit_cronchg" "$audit_unitchg" "$managerlog")"

    local msg
    msg=$(
cat <<MSG
⚠️ ALERT: SERVICE BERHENTI

Host   : ${HOSTNAME_FQDN}
Target : ${unit}
Waktu  : $(date '+%F %T %Z')
Mode   : ${MONITOR_MODE}
Ringkas: ${cause}

[systemctl show]
$(trim_block "$props" 30)

[Audit - service control]
$(trim_block "$(filter_audit_for_target "$audit_ctrl" "$unit")" 35)

[Audit - kill path]
$(trim_block "$(filter_audit_for_target "$audit_kill" "$unit")" 25)

[Audit - power path]
$(trim_block "$audit_power" 20)

[Audit - cron exec]
$(trim_block "$audit_cron" 20)

[Audit - cron changed]
$(trim_block "$audit_cronchg" 20)

[Audit - unit changed]
$(trim_block "$audit_unitchg" 20)

[Journal unit]
$(trim_block "$unitlog" 35)

[Journal manager/cron]
$(trim_block "$managerlog" 35)
MSG
)
    send_tg "$msg"
}

find_proc_pids() {
    local name="$1"
    pgrep -x "$name" 2>/dev/null || pgrep -f "(^|/)$name([[:space:]]|$)" 2>/dev/null || true
}

recent_proc_context() {
    local name="$1"
    local rx
    rx="$(escape_regex "$name")"

    if has_cmd journalctl; then
        safe_cmd journalctl --since "$SINCE_WINDOW" --no-pager -o short-iso \
            | grep -Ei "${rx}|CRON|cron|shutdown|reboot|poweroff|halt|docker|containerd|systemd" \
            | tail -n "$MGR_JOURNAL_LINES"
    elif [[ -f /var/log/syslog ]]; then
        grep -Ei "${rx}|CRON|cron|shutdown|reboot|poweroff|halt|docker|containerd" /var/log/syslog | tail -n "$MGR_JOURNAL_LINES" || true
    else
        ps -ef | grep -E "$rx" | grep -v grep | tail -n 20 || true
    fi
}

proc_stop_report() {
    local name="$1"
    sleep 1

    local ctx cause
    ctx="$(recent_proc_context "$name")"
    cause="$(guess_cause_proc "$name" "$ctx")"

    local msg
    msg=$(
cat <<MSG
⚠️ ALERT: PROSES BERHENTI

Host   : ${HOSTNAME_FQDN}
Target : ${name}
Waktu  : $(date '+%F %T %Z')
Mode   : ${MONITOR_MODE}
Ringkas: ${cause}

[Context log]
$(trim_block "$ctx" 40)

[Catatan]
Mode process-only dipakai karena systemd tidak aktif sebagai PID 1.
Untuk bukti yang benar-benar pasti tentang siapa yang stop container/proses, perlu log dari host/container runtime.
MSG
)
    send_tg "$msg"
}

monitor_systemd_targets() {
    declare -A STATE=()

    for t in "${TARGETS_ARR[@]}"; do
        if unit_exists "$t"; then
            STATE["$t"]="$(safe_cmd systemctl is-active "$t")"
        else
            STATE["$t"]="missing"
        fi
    done

    while true; do
        sleep "$CHECK_INTERVAL"

        for t in "${TARGETS_ARR[@]}"; do
            local current
            if unit_exists "$t"; then
                current="$(safe_cmd systemctl is-active "$t")"
            else
                current="missing"
            fi

            if [[ "${STATE[$t]}" == "active" && "$current" != "active" ]]; then
                service_stop_report_systemd "$t"
            fi

            STATE["$t"]="$current"
        done
    done
}

monitor_proc_targets() {
    declare -A STATE=()

    for t in "${TARGETS_ARR[@]}"; do
        STATE["$t"]="$(find_proc_pids "$t" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    done

    while true; do
        sleep "$CHECK_INTERVAL"

        for t in "${TARGETS_ARR[@]}"; do
            local current
            current="$(find_proc_pids "$t" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

            if [[ -n "${STATE[$t]}" && -z "$current" ]]; then
                proc_stop_report "$t"
            fi

            STATE["$t"]="$current"
        done
    done
}

monitor_files() {
    local watch_paths=()

    [[ -e /etc/shadow ]] && watch_paths+=("/etc/shadow")
    [[ -d /etc/ssh ]] && watch_paths+=("/etc/ssh")
    [[ -d /etc/ssh/sshd_config.d ]] && watch_paths+=("/etc/ssh/sshd_config.d")

    if [[ ${#watch_paths[@]} -eq 0 ]]; then
        return 0
    fi

    inotifywait -m -r \
        -e modify,attrib,close_write,moved_to,create,delete,move \
        --format '%w|%e|%f' \
        "${watch_paths[@]}" 2>/dev/null |
    while IFS='|' read -r directory _events filename; do
        local filepath="${directory}${filename}"
        sleep 1

        if [[ "$filepath" == "/etc/shadow" || "$filepath" == *"/shadow" ]]; then
            password_change_report
        fi

        if [[ "$filepath" == *"/sshd_config"* || "$filepath" == *"/ssh/"* || "$filepath" == *"/sshd_config.d/"* ]]; then
            ssh_change_report
        fi
    done
}

send_boot_message() {
    local targets_text
    targets_text="$(printf '%s, ' "${TARGETS_ARR[@]}" | sed 's/, $//')"

    send_tg "🛡️ System Health Monitor aktif di ${HOSTNAME_FQDN}

Target dipantau: ${targets_text}
Mode          : ${MONITOR_MODE}
Virtualisasi  : ${VIRT_TYPE:-unknown}
Systemd       : ${HAS_SYSTEMD}
Audit         : ${AUDIT_AVAILABLE}"
}

main() {
    send_boot_message

    if [[ "${HAS_SYSTEMD:-0}" == "1" ]]; then
        monitor_systemd_targets &
    else
        monitor_proc_targets &
    fi

    monitor_files &
    wait
}

main
EOF
chmod 700 "$MONITOR_BIN"

# =========================
# AUTOSTART
# =========================
log "[7/9] Menyiapkan autostart..."
if [[ "$HAS_SYSTEMD" -eq 1 ]]; then
    cat > "$SYSTEMD_UNIT" <<'EOF'
[Unit]
Description=System Health Monitor (Telegram + Forensic)
After=network-online.target systemd-journald.service
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/local/bin/system-health-monitor.sh
Restart=always
RestartSec=3
User=root
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable system-health-monitor.service >/dev/null
    systemctl restart system-health-monitor.service
else
    mkdir -p "$(dirname "$RUN_LOG")"
    nohup "$MONITOR_BIN" >>"$RUN_LOG" 2>&1 &
    echo $! > /run/system-health-monitor.pid || true
fi

# =========================
# RINGKASAN
# =========================
log "[8/9] Verifikasi singkat..."
if [[ "$HAS_SYSTEMD" -eq 1 ]]; then
    systemctl status system-health-monitor.service --no-pager >/dev/null 2>&1 || true
else
    ps -fp "$(cat /run/system-health-monitor.pid 2>/dev/null || echo 0)" >/dev/null 2>&1 || true
fi

log "[9/9] Selesai."
echo
echo "============================================================"
echo "SELESAI"
echo "============================================================"
echo "Virtualisasi : $VIRT_TYPE"
echo "Systemd      : $HAS_SYSTEMD"
echo "Audit        : $AUDIT_AVAILABLE"
echo "Mode         : $MONITOR_MODE"
echo "ENV file     : $ENV_FILE"
echo "Monitor bin  : $MONITOR_BIN"
echo "Baseline     : $BASELINE_DIR/$TS"
echo
if [[ "$HAS_SYSTEMD" -eq 1 ]]; then
    echo "Cek:"
    echo "  systemctl status system-health-monitor --no-pager"
    echo "  journalctl -u system-health-monitor -n 50 --no-pager"
    echo "  systemctl status auditd --no-pager"
else
    echo "Cek:"
    echo "  ps -fp \$(cat /run/system-health-monitor.pid)"
    echo "  tail -n 50 $RUN_LOG"
    echo
    echo "Catatan:"
    echo "  Non-systemd/container mode sudah jalan saat ini, tetapi persistensi"
    echo "  setelah container restart harus diatur dari host/runtime container."
fi
echo "============================================================"