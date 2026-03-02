#!/bin/bash

# curl -sL -o /etc/udp/config.json https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/config.json && systemctl restart udp-custom && sleep 2 && systemctl status udp-custom

echo "================================================="
echo " MEMPERBAIKI CONFIG JSON UDP-CUSTOM "
echo "================================================="

# Lokasi target dan URL download
TARGET_DIR="/etc/udp"
CONFIG_FILE="$TARGET_DIR/config.json"
URL="https://raw.githubusercontent.com/ica4me/auto-script-free/main/udp-custom/config.json"

echo "==> [1/3] Memastikan direktori $TARGET_DIR ada..."
mkdir -p $TARGET_DIR

echo "==> [2/3] Mengunduh dan menimpa file config.json..."
curl -sL -o $CONFIG_FILE $URL

if [ $? -eq 0 ]; then
    echo "✅ File config.json berhasil diunduh!"
else
    echo "❌ Gagal mengunduh file. Periksa koneksi internet Anda."
    exit 1
fi

echo "==> [3/3] Merestart service udp-custom..."
systemctl restart udp-custom

echo "Menunggu service berjalan..."
sleep 3

# Cek apakah service berhasil berjalan
STATUS=$(systemctl is-active udp-custom)
if [ "$STATUS" == "active" ]; then
    echo "✅ SUKSES! Service udp-custom kembali [ON]."
else
    echo "❌ Gagal! Service udp-custom masih bermasalah."
fi
echo "================================================="