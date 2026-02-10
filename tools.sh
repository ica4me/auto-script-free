#!/bin/bash
clear
red='\e[1;31m'
green2='\e[1;32m'
yell='\e[1;33m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }


#!/bin/bash

echo "           Tools install...!"
echo "                  Progress..."
sleep 0.1

# Update dan upgrade sistem
apt update -y && apt upgrade -y && apt dist-upgrade -y
apt install sudo -y

# Bersihkan cache apt
sudo apt-get clean all

# Instalasi utilitas penting
apt install -y debconf-utils haproxy p7zip-full software-properties-common --no-install-recommends

# Hapus firewall bawaan yang tidak dibutuhkan
apt-get remove --purge -y ufw firewalld exim4

# Bersihkan paket tidak terpakai
apt-get autoremove -y

# Konfigurasi iptables agar autosave aktif
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# Instalasi paket tambahan
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install \
  iptables iptables-persistent netfilter-persistent figlet ruby libxml-parser-perl \
  squid nmap screen curl jq bzip2 gzip coreutils rsyslog iftop htop zip unzip net-tools \
  sed gnupg gnupg1 bc apt-transport-https build-essential dirmngr libxml-parser-perl \
  neofetch screenfetch lsof openssl openvpn easy-rsa fail2ban tmux stunnel4 squid \
  dropbear socat cron bash-completion ntpdate xz-utils apt-transport-https gnupg2 \
  dnsutils lsb-release chrony libnss3-dev libnspr4-dev pkg-config libpam0g-dev \
  libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-openssl-dev flex bison make \
  libnss3-tools libevent-dev xl2tpd apt git speedtest-cli p7zip-full libjpeg-dev \
  zlib1g-dev python-is-python3 python3-pip shc build-essential nodejs nginx php \
  php-fpm php-cli php-mysql p7zip-full squid libcurl4-openssl-dev

# Instalasi gotop
gotop_latest="$(curl -s https://api.github.com/repos/xxxserxxx/gotop/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"
gotop_link="https://github.com/xxxserxxx/gotop/releases/download/v$gotop_latest/gotop_v"$gotop_latest"_linux_amd64.deb"
curl -sL "$gotop_link" -o /tmp/gotop.deb
dpkg -i /tmp/gotop.deb

# Bersihkan file yang tidak diperlukan
sudo apt-get autoclean -y >/dev/null 2>&1
sudo apt-get -y --purge remove \
  samba* apache2* bind9* sendmail* unscd >/dev/null 2>&1
apt autoremove -y >/dev/null 2>&1

echo "           Instalasi selesai!"


yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
yellow "Dependencies successfully installed..."
mkdir -p /etc/xray
mkdir -p /etc/bot
mkdir -p /etc/vmess
mkdir -p /etc/limit
mkdir -p /etc/kyt/limit/ssh
mkdir -p /etc/kyt/limit/vmess
mkdir -p /etc/kyt/limit/vless
mkdir -p /etc/kyt/limit/trojan
mkdir -p /etc/vless
mkdir -p /etc/trojan
mkdir -p /root/udp
clear
rm -r tools.sh
