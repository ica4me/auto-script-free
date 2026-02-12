#!/bin/bash

# === KONFIGURASI REPO ANDA ===
REPO="https://raw.githubusercontent.com/ica4me/auto-script-free/main/"

# === Variabel awal ===
NS=$(cat /etc/xray/dns 2>/dev/null)
PUB=$(cat /etc/slowdns/server.pub 2>/dev/null)
domain=$(cat /etc/xray/domain 2>/dev/null)

grenbo="\e[92;1m"
NC='\e[0m'

# === Membersihkan cache dpkg ===
echo -e "[INFO] Membersihkan lock file APT..."
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/dpkg/statoverride
dpkg --configure -a

# === Hapus file/service lama ===
echo -e "[INFO] Menghapus service lama..."
systemctl stop kyt 2>/dev/null
rm -f /etc/systemd/system/kyt.service
rm -rf /usr/bin/kyt /usr/bin/bot /usr/bin/kyt.* /usr/bin/bot.* /root/kyt.zip /root/bot.zip /usr/bin/venv

# === Update dan Install dependencies System ===
echo -e "[INFO] Update dan install package penting..."
apt update && apt upgrade -y
apt install -y unzip neofetch python3 python3-pip git wget curl figlet lolcat software-properties-common
apt install -y python3-venv

# === Setup Python virtual environment ===
echo -e "[INFO] Membuat virtual environment Python..."
cd /usr/bin
python3 -m venv venv
source /usr/bin/venv/bin/activate
pip install --upgrade pip

# === Download dan Pasang File BOT ===
echo -e "[INFO] Download & pasang bot scripts..."
cd /usr/bin
wget -q -O bot.zip "${REPO}bot/bot.zip"
unzip -o bot.zip
rm -f bot.zip
# Pindahkan isi folder bot (jika ada) ke /usr/bin
if [ -d "bot" ]; then
    mv bot/* /usr/bin
    rm -rf bot
fi
chmod +x /usr/bin/*

# === Download dan Pasang File KYT (Panel Bot) ===
echo -e "[INFO] Download & pasang KYT panel..."
cd /usr/bin
wget -q -O kyt.zip "${REPO}bot/kyt.zip"
unzip -o kyt.zip -d /usr/bin/
rm -f kyt.zip

# === Install Python Dependencies ===
echo -e "[INFO] Installing Python modules..."
cd /usr/bin/kyt
# Install library wajib
/usr/bin/venv/bin/pip install requests telethon paramiko pytz
# Jika ada requirements.txt, install juga
if [ -f "requirements.txt" ]; then
    /usr/bin/venv/bin/pip install -r requirements.txt
fi
cd

# === Konfigurasi Bot Telegram ===
clear
figlet "Xwan VPN" | lolcat
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \e[1;97;101m          ADD BOT PANEL          \e[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "${grenbo}Tutorial Create Bot dan ID Telegram${NC}"
echo -e "${grenbo}[*] Buat Bot dan Token : @BotFather${NC}"
echo -e "${grenbo}[*] Cek ID Telegram : @MissRose_bot, perintah /info${NC}"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -e -p "[*] Masukkan Bot Token Anda : " bottoken
read -e -p "[*] Masukkan ID Telegram Anda : " admin

# === Simpan Konfigurasi (Environment Variables) ===
mkdir -p /etc/bot
mkdir -p /usr/bin/kyt

cat <<EOF > /usr/bin/kyt/var.txt
BOT_TOKEN="$bottoken"
ADMIN="$admin"
DOMAIN="$domain"
PUB="$PUB"
HOST="$NS"
EOF

# Database legacy (cadangan)
echo "#bot# $bottoken $admin" > /etc/bot/.bot.db

# === Buat Service Systemd ===
cat >/etc/systemd/system/kyt.service <<EOF
[Unit]
Description=App Bot kyt Service
After=network.target network-online.target systemd-user-sessions.service time-sync.target
Wants=network-online.target

[Service]
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash -c 'source /usr/bin/venv/bin/activate && cd /usr/bin/kyt && python3 -m kyt'
Restart=always
User=root
Environment=PATH=/usr/bin:/usr/local/bin:/usr/bin/venv/bin
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/usr/bin/kyt/var.txt
WorkingDirectory=/usr/bin/kyt
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# === Aktifkan Service ===
systemctl daemon-reload
systemctl enable --now kyt

# === Output Selesai ===
clear
echo -e "\e[92mInstalasi Bot Selesai!\e[0m"
echo "==============================="
echo "Token Bot     : $bottoken"
echo "Admin ID      : $admin"
echo "Domain        : $domain"
echo "==============================="
echo "Silakan cek bot telegram Anda dan ketik /menu"