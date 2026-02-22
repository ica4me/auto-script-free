#!/bin/bash

# --- KONFIGURASI GITHUB ---
GITHUB_TOKEN="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" # Masukkan Token GitHub kamu di sini
REPO_OWNER="ica4me"
REPO_NAME="auto-script-free"
FILE_PATH="romsip"
BRANCH="main"

echo "Mendeteksi IP VPS..."
IP_VPS=$(curl -4 -sS ifconfig.me)

if [ -z "$IP_VPS" ]; then
    echo "❌ Gagal mendapatkan IP VPS. Cek koneksi internet."
    exit 1
fi

echo "IP Publik: $IP_VPS"

# Format teks yang akan ditambahkan
NEW_LINE="### admin 2099-12-31 $IP_VPS @VIP"

# URL API GitHub
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents/$FILE_PATH"

# 1. Mengambil data file dari GitHub (untuk mendapatkan SHA dan isi lama)
echo "Menghubungi GitHub API..."
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "$API_URL")

SHA=$(echo "$RESPONSE" | jq -r .sha)

if [ "$SHA" == "null" ]; then
    echo "❌ Error: File tidak ditemukan atau Token salah/kadaluarsa."
    exit 1
fi

# 2. Decode isi file lama dari Base64
OLD_CONTENT=$(echo "$RESPONSE" | jq -r .content | base64 --decode)

# Cek apakah IP sudah ada di dalam file agar tidak dobel
if echo "$OLD_CONTENT" | grep -q "$IP_VPS"; then
    echo "⚠️ IP $IP_VPS sudah terdaftar di dalam file romsip."
    exit 0
fi

# 3. Gabungkan isi lama dengan baris baru, lalu encode ke Base64
NEW_CONTENT=$(printf "%s\n%s" "$OLD_CONTENT" "$NEW_LINE")
# Harus tanpa newline agar JSON valid saat dikirim
NEW_CONTENT_B64=$(echo -n "$NEW_CONTENT" | base64 | tr -d '\n')

# 4. Kirim pembaruan ke GitHub (Update File)
echo "Menyimpan baris baru ke GitHub..."
JSON_PAYLOAD=$(jq -n \
  --arg msg "Auto-add IP $IP_VPS" \
  --arg content "$NEW_CONTENT_B64" \
  --arg sha "$SHA" \
  --arg branch "$BRANCH" \
  '{message: $msg, content: $content, sha: $sha, branch: $branch}')

UPDATE_RESPONSE=$(curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$JSON_PAYLOAD" \
  "$API_URL")

# Cek apakah berhasil
if echo "$UPDATE_RESPONSE" | jq -e .content.sha >/dev/null; then
    echo "✅ SUKSES! IP $IP_VPS telah ditambahkan ke GitHub."
else
    echo "❌ Gagal mengupdate file. Pesan error dari GitHub:"
    echo "$UPDATE_RESPONSE" | jq -r .message
fi