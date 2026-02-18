#!/bin/bash
# ==================================================
# Script Setup & Update Menu VPS
# ==================================================

# -----------------------------
# Fungsi Animasi Loading
# -----------------------------
loading() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    tput civis
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf " [%c] $message\r" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    tput cnorm
}

# -----------------------------
# Install p7zip jika belum ada
# -----------------------------
if ! command -v 7z &> /dev/null; then
    echo -e " [INFO] Installing p7zip-full..."
    apt install p7zip-full -y &> /dev/null &
    loading $! "Loading Install p7zip-full"
fi

# -----------------------------
# Variabel Server & User
# -----------------------------
domain=$(cat /etc/xray/domain)
MYIP=$(curl -sS ipv4.icanhazip.com)
username="admin"
valid="2099-12-31"
today=$(date +"%Y-%m-%d")
d1=$(date -d "$valid" +%s)
d2=$(date -d "$today" +%s)
certifacate=$(((d1 - d2) / 86400))

# Mendapatkan tanggal dari server
echo -e " [INFO] Fetching server date..."
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=$(date +"%Y-%m-%d" -d "$dateFromServer")

# Repository
REPO="https://raw.githubusercontent.com/ica4me/auto-script-free/main/"
pwadm="@Ridwan112#"
Username="xwan"
Password="$pwadm"

# -----------------------------
# Download & Setup Menu
# -----------------------------
echo -e " [INFO] Downloading menu.zip..."
{
    > /etc/cron.d/cpu_otm

    cat > /etc/cron.d/cpu_xwan <<END
#
END

    wget -O /usr/bin/autocpu "${REPO}install/autocpu.sh" && chmod +x /usr/bin/autocpu
    wget -q ${REPO}menu/menu.zip
    mv menu/expsc /usr/local/sbin/expsc
    
    echo -e " [INFO] Extracting menu..."
    7z x menu.zip &> /dev/null
    
    chmod +x menu/*
    
    # Pindahkan ke folder sistem
    echo -e " [INFO] Installing menu..."
    mv menu/* /usr/local/sbin

    # Cleanup
    rm -rf menu menu.zip
    rm -rf /usr/local/sbin/*~ /usr/local/sbin/gz* /usr/local/sbin/*.bak
    cd /usr/local/sbin
    sed -i 's/\r//' quota
    cd
} &> /dev/null &
loading $! "Loading Extract and Setup menu"

# -----------------------------
# Ambil versi server
# -----------------------------
echo -e " [INFO] Fetching server version..."
serverV=$(curl -sS ${REPO}versi)
echo $serverV > /opt/.ver

# Cleanup
rm /root/*.sh*

echo -e " [INFO] File download and setup completed successfully. Version: $serverV!"
exit 0
