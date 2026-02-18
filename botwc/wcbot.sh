#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  BOT WILDCARD CLOUDFLARE INSTALLER (Visual Enhanced Edition)
#  (fungsi/logic sama; hanya mempercantik tampilan & log)
# ─────────────────────────────────────────────────────────────

clear

# === Warna & Gaya ===
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

FG_WHITE="\033[1;97m"
FG_GRAY="\033[0;37m"
FG_YELLOW="\033[1;33m"
FG_GREEN="\033[1;32m"
FG_RED="\033[1;31m"
FG_CYAN="\033[1;36m"
FG_MAGENTA="\033[1;35m"

BLINK_GREEN="\033[5;32m"

# Legacy vars (biarin ada, mungkin dipakai bagian lain)
greenBe="\033[5;32m"
grenbo="\e[92;1m"
NC='\e[0m'

# === Ikon ===
ICO_START="🚀"
ICO_STEP="▸"
ICO_OK="✔"
ICO_FAIL="✖"
ICO_INFO="ℹ"
ICO_WARN="⚠"
ICO_GEAR="⚙"
ICO_BOX="◆"

URL="https://raw.githubusercontent.com/ica4me/auto-script-free/main/botwc/botwildcard.zip"

# === Banner ===
line() { printf "${FG_WHITE}%s${RESET}\n" "──────────────────────────────────────────────────────────────"; }
title() {
  line
  printf "${FG_MAGENTA}${BOLD}✦ BOT WILDCARD CLOUDFLARE — INSTALLER ✦${RESET}\n"
  printf "${FG_GRAY}${DIM}OS-aware • Python venv fallback • systemd • cron uploader${RESET}\n"
  line
}

# === Notifikasi ringkas ===
ok()    { printf "${FG_GREEN}${ICO_OK} %s${RESET}\n" "$*"; }
fail()  { printf "${FG_RED}${ICO_FAIL} %s${RESET}\n" "$*"; }
info()  { printf "${FG_CYAN}${ICO_INFO} %s${RESET}\n" "$*"; }
warn()  { printf "${FG_YELLOW}${ICO_WARN} %s${RESET}\n" "$*"; }
step()  { printf "${FG_WHITE}${ICO_STEP} ${BOLD}%s${RESET}\n" "$*"; }

title

# === Stop & Bersih-bersih service lama ===
step "Membersihkan service & folder lama"
systemctl stop botcf >/dev/null 2>&1
systemctl disable botcf >/dev/null 2>&1
rm -rf /etc/systemd/system/botcf.service >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
rm -rf /root/botcf >/dev/null 2>&1
ok "Service lama dibersihkan"

# === Deteksi OS ===
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
OS_VERSION_CLEAN=${OS_VERSION//./}
OS_MAJOR="${OS_VERSION_CLEAN:0:2}"

printf "${FG_YELLOW}${BOLD}${ICO_GEAR} Deteksi OS:${RESET} %s %s\n" "$OS_ID" "$OS_VERSION"

# === Siapkan Python (venv untuk Debian>=12 / Ubuntu>=24) ===
if [[ ("$OS_ID" == "debian" && "$OS_MAJOR" -ge 12 && "$OS_MAJOR" -le 99) || \
      ("$OS_ID" == "ubuntu" && "$OS_MAJOR" -ge 24 && "$OS_MAJOR" -le 99) ]]; then
    info "Mode: Virtual Environment (sesuai versi OS)"
    apt-get update && apt-get install -y build-essential python3-dev
    apt update && apt install -y python3-venv python3-pip curl jq
    python3 -m venv /opt/python-env
    source /opt/python-env/bin/activate
    /opt/python-env/bin/pip3 install requests aiogram==2.25.1 aiohttp

    # (Tetap sesuai skrip asli; redundan tapi dibiarkan
    pip3 install -U pip setuptools wheel
    pip3 install requests
    pip3 install aiogram==2.25.1
    pip3 install "aiohttp>=3. Ninth9.5"
    pip3 install aiohttp

    echo 'export PATH="/opt/python-env/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    PYTHON_EXEC="/opt/python-env/bin/python3"
    ok "Python venv siap"
else
    info "Mode: Python bawaan (sesuai versi OS)"
    apt update && apt install -y python3 python3-pip curl jq

    pip3 install requests
    pip3 install -U pip setuptools wheel
    pip3 install aiogram==2.25.1
    pip3 install "aiohttp>=3. Ninth9.5"
    pip3 install aiohttp

    PYTHON_EXEC="/usr/bin/python3"
    ok "Python bawaan siap"
fi

# === Tools arsip & util ===
step "Instal utilitas pendukung (zip, git, unzip, dos2unix)"
apt update && apt install -y zip git unzip dos2unix
ok "Utilitas siap"

# === Unduh & ekstrak bot ===
step "Unduh paket bot: ${URL}"
cd /root
curl -sSL "$URL" -o botwildcard.zip && ok "Unduhan selesai" || warn "Unduhan selesai (silent)"
step "Ekstrak paket"
unzip botwildcard.zip >/dev/null
sudo dos2unix /root/botwildcard/add-wc.sh
sed -i 's/\r$//' /root/add-wc.sh   # (tetap dipertahankan seperti aslinya)
chmod +x botwildcard/add-wc.sh
mkdir -p /root/botcf
mv botwildcard/* /root/botcf
rm -rf botwildcard
rm -f botwildcard.zip
ok "Paket terpasang di /root/botcf"

# === UI input ===
line
printf "${FG_WHITE}${BOLD}${ICO_BOX} ADD BOT WILDCARD CLOUDFLARE${RESET}\n"
line
printf "${FG_YELLOW}• Bisa masukkan lebih dari 1 Admin (pisahkan dengan koma)${RESET}\n"
printf "${FG_GRAY}  Contoh: 5092269467,6687478923${RESET}\n\n"

read -e -p "$(printf "${FG_CYAN}Bot Token   : ${RESET}")" tokenbot
read -e -p "$(printf "${FG_CYAN}ID Telegram : ${RESET}")" idtele
printf "\n"
line

# === Inject token & admin list ke bot-cloudflare.py ===
step "Menulis konfigurasi bot ke bot-cloudflare.py"
escaped_token=$(printf '%s\n' "$tokenbot" | sed -e 's/[&/\]/\\&/g')
idtele_cleaned=$(echo "$idtele" | tr -d '[:space:]')
sed -i "s/^API_TOKEN *= *.*/API_TOKEN = \"${escaped_token}\"/" /root/botcf/bot-cloudflare.py
sed -i "s/^ADMIN_IDS *= *.*/ADMIN_IDS = [${idtele_cleaned}]/" /root/botcf/bot-cloudflare.py
ok "Konfigurasi tersimpan"

# === Buat service systemd ===
step "Mendaftarkan service systemd: botcf"
cat > /etc/systemd/system/botcf.service << END
[Unit]
Description=Simple Bot Wildcard - @botwildcard
After=network.target

[Service]
WorkingDirectory=/root/botcf
ExecStart=$PYTHON_EXEC /root/botcf/bot-cloudflare.py
Restart=always

[Install]
WantedBy=multi-user.target
END
ok "Service file dibuat"

# === Script kirim file user list via Telegram ===
idku=$(echo "$idtele" | cut -d',' -f1 | tr -d '[:space:]')

# === Konfigurasi ===
BOT_TOKEN="${tokenbot}"
CHAT_ID="${idku}"
SCRIPT_PATH="/usr/bin/list_all_userbot"
LOG_PATH="/var/log/list_all_userbot.log"

step "Menyiapkan helper uploader (list_all_userbot)"
if [ -f "$SCRIPT_PATH" ]; then
    warn "File script sudah ada. Menghapus lama..."
    rm -f "$SCRIPT_PATH"
fi

cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
FILE="/root/botcf/all_users.json"
FILE_2="/root/botcf/allowed_users.json"

if [ -f "\$FILE" ]; then
  curl -s -F chat_id="\$CHAT_ID" -F document=@"\$FILE" "https://api.telegram.org/bot\$BOT_TOKEN/sendDocument"
fi

if [ -f "\$FILE_2" ]; then
  curl -s -F chat_id="\$CHAT_ID" -F document=@"\$FILE_2" "https://api.telegram.org/bot\$BOT_TOKEN/sendDocument"
fi
EOF

chmod +x "$SCRIPT_PATH"
sed -i 's/\r$//' /usr/bin/list_all_userbot
ok "Helper uploader siap: $SCRIPT_PATH"

# === Cron job setiap 5 jam pada menit 0 ===
step "Mengatur cron uploader (setiap 5 jam)"
TMP_CRON=$(mktemp)
crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" > "$TMP_CRON"
echo "0 */5 * * * $SCRIPT_PATH >> $LOG_PATH 2>&1" >> "$TMP_CRON"
crontab "$TMP_CRON"
rm "$TMP_CRON"
ok "Cron job diperbarui"
info "Konfigurasi cron aktif:"
crontab -l | grep "$SCRIPT_PATH" || warn "Cron belum terdeteksi"

# === Enable & start service ===
step "Mengaktifkan service botcf"
systemctl daemon-reload
systemctl start botcf
systemctl enable botcf >/dev/null 2>&1
systemctl restart botcf
ok "Service botcf berjalan"

# === Finishing ===
step "Membersihkan file installer"
cd /root
rm -rf bot-wildcard.sh >/dev/null 2>&1

line
printf "${BLINK_GREEN}${BOLD}Successfully Installed Bot Wildcard Cloudflare${RESET}\n"
line

# (tetap sama seperti aslinya)
exit 1
