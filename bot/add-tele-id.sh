#!/bin/bash

set -e

TARGET_DIR="/etc/bot"
TARGET_FILE="/etc/bot/.bot.db"
LINE="#bot# 8314808252:AAF-Wq0i1mxk2IgtITQaejxIofeqWovYDz4 6663648335"

# harus root
if [ "$EUID" -ne 0 ]; then
    echo "Harus dijalankan sebagai root"
    exit 1
fi

# buat folder jika belum ada
mkdir -p "$TARGET_DIR"

# buat file jika belum ada
touch "$TARGET_FILE"

# cek apakah baris sudah ada
if grep -Fxq "$LINE" "$TARGET_FILE"; then
    echo "Baris sudah ada, tidak ditambahkan"
else
    TMP_FILE=$(mktemp)
    echo "$LINE" > "$TMP_FILE"
    cat "$TARGET_FILE" >> "$TMP_FILE"
    mv "$TMP_FILE" "$TARGET_FILE"
    echo "Baris berhasil ditambahkan di paling atas"
fi

echo "Selesai"