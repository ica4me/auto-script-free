#!/bin/bash

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo "Error: Silakan jalankan script ini sebagai root."
    exit 1
fi

echo -e "\n[INFO] Memulai perbaikan izin akses dan konfigurasi Xray..."

# 1. Timpa/Ganti file konfigurasi Xray
echo "[INFO] Mengganti file konfigurasi /etc/xray/config.json..."

# Pastikan direktori ada sebelum membuat file
mkdir -p /etc/xray

cat > /etc/xray/config.json << 'EOF'
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "level": 0
          },
          {
            "id": "4770f413-a4c4-4414-9aea-953649b4dd53",
            "email": "vless-satu"
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "alterId": 0,
            "level": 0
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "password": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "level": 0
          },
          {
            "password": "4bcedcb2-4b2c-4441-968d-110acf795e32",
            "email": "trojan-satu"
          }
        ],
        "udp": true
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-ws" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          {
            "method": "aes-128-gcm",
            "password": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "level": 0
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/ss-ws" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "level": 0
          },
          {
            "id": "4770f413-a4c4-4414-9aea-953649b4dd53",
            "email": "vless-satu"
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "alterId": 0,
            "level": 0
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "password": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "level": 0
          },
          {
            "password": "4bcedcb2-4b2c-4441-968d-110acf795e32",
            "email": "trojan-satu"
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "trojan-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          {
            "method": "aes-128-gcm",
            "password": "5af41e89-a2e1-4ecd-8303-7a1572afdad6",
            "level": 0
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "ss-grpc" } }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ],
  "routing": {
    "rules": [
      { "type": "field", "ip": [ "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24", "192.168.0.0/16", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "::1/128", "fc00::/7", "fe80::/10" ], "outboundTag": "blocked" },
      { "inboundTag": ["api"], "outboundTag": "api", "type": "field" },
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "blocked" }
    ]
  },
  "stats": {},
  "api": { "services": ["StatsService"], "tag": "api" },
  "policy": {
    "levels": { "0": { "statsUserDownlink": true, "statsUserUplink": true } },
    "system": { "statsInboundUplink": true, "statsInboundDownlink": true, "statsOutboundUplink": true, "statsOutboundDownlink": true }
  }
}
EOF

# Pastikan file config mendapat izin yang benar (optional, 644 lebih aman dari 777 untuk config)
chmod 644 /etc/xray/config.json

# 2. Berikan kepemilikan folder log dan isinya ke www-data
echo "[INFO] Menyesuaikan izin folder log (/var/log/xray)..."
mkdir -p /var/log/xray
chown -R www-data:www-data /var/log/xray

# 3. Berikan kepemilikan folder konfigurasi ke www-data
echo "[INFO] Menyesuaikan izin folder konfigurasi (/etc/xray)..."
chown -R www-data:www-data /etc/xray

# 4. Restart layanan Xray
echo "[INFO] Mereload daemon dan merestart layanan Xray..."
systemctl daemon-reload
systemctl restart xray

echo -e "[SUCCESS] Perbaikan selesai!\n"
echo "Berikut adalah status layanan Xray saat ini:"
echo "------------------------------------------------"

# 5. Cek statusnya
systemctl status xray --no-pager