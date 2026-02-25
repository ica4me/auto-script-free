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
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },

    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "alterId": 0,
            "level": 0,
            "email": "template-vmess"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "template-trojan-password",
            "level": 0,
            "email": "template-trojan"
          }
        ],
        "udp": true
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan-ws"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          {
            "method": "aes-128-gcm",
            "password": "template-ss-password",
            "level": 0,
            "email": "template-ss"
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ss-ws"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vless-grpc"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "alterId": 0,
            "level": 0,
            "email": "template-vmess"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vmess-grpc"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "template-trojan-password",
            "level": 0,
            "email": "template-trojan"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "trojan-grpc"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          {
            "method": "aes-128-gcm",
            "password": "template-ss-password",
            "level": 0,
            "email": "template-ss"
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "ss-grpc"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "blocked"
      }
    ]
  },
  "stats": {},
  "api": {
    "services": ["StatsService"],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  }
}
EOF

# Pastikan file config mendapat izin yang benar
chmod 755 /etc/xray
chown root:www-data /etc/xray/config.json
chmod 640 /etc/xray/config.json
chown -R www-data:www-data /var/log/xray

# 2. Berikan kepemilikan folder log dan isinya ke www-data
echo "[INFO] Menyesuaikan izin folder log (/var/log/xray)..."
mkdir -p /var/log/xray
chown -R www-data:www-data /var/log/xray

# 3. Berikan kepemilikan folder konfigurasi ke www-data
echo "[INFO] Menyesuaikan izin folder konfigurasi (/etc/xray)..."
chown -R www-data:www-data /etc/xray

# 4. Memperbaiki format newline pada script menu (CRLF ke LF)
echo "[INFO] Memperbaiki format script..."
# =====Keluarga-vless====
sed -i 's/\r$//' /usr/local/sbin/xray-vless-lib /usr/local/sbin/add-vle /usr/local/sbin/member-vle /usr/local/sbin/check-vle \
  /usr/local/sbin/change-vless-qouta /usr/local/sbin/ganti-ip-vless /usr/local/sbin/renew-vle \
  /usr/local/sbin/del-vle /usr/local/sbin/lock-vl /usr/local/sbin/unlock-vl /usr/local/sbin/recover-vl /usr/local/sbin/trial-vle
# =====Keluarga-vless====
sed -i 's/\r$//' /usr/local/sbin/xray-vmess-lib
dos2unix /usr/local/sbin/add-vme 2>/dev/null || sed -i 's/\r$//' /usr/local/sbin/add-vme

# 5. Restart layanan Xray
echo "[INFO] Mereload daemon dan merestart layanan Xray..."
systemctl daemon-reload
systemctl restart xray

echo -e "[SUCCESS] Perbaikan selesai!\n"
echo "Berikut adalah status layanan Xray saat ini:"
echo "------------------------------------------------"

# 6. Cek statusnya
sudo -u www-data /usr/local/bin/xray run -test -c /etc/xray/config.json
systemctl status xray --no-pager