#!/bin/bash
# ==========================================
# Script Iptables NAT Repair (ZIVPN & WG Fix)
# ==========================================

# Warna untuk output terminal
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${YELLOW}      REPAIR IPTABLES NAT PREROUTING      ${NC}"
echo -e "${CYAN}==========================================${NC}"

# 1. Hapus aturan ZIVPN yang duplikat/salah (Diulang sampai bersih)
echo -e "${GREEN}[*] Membersihkan rule ZIVPN & WG lama...${NC}"
while iptables -t nat -D PREROUTING -p udp -m udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null; do true; done
while iptables -t nat -D PREROUTING -p udp -m udp --dport 65535 -j RETURN 2>/dev/null; do true; done

# 2. Masukkan aturan baru di urutan teratas
echo -e "${GREEN}[*] Memasukkan rule baru...${NC}"
iptables -t nat -I PREROUTING 1 -p udp -m udp --dport 65535 -j RETURN
iptables -t nat -I PREROUTING 2 -p udp -m udp --dport 6000:19999 -j DNAT --to-destination :5667

# 3. Simpan Iptables secara Permanen (Agar aman saat reboot)
echo -e "${GREEN}[*] Menyimpan Iptables secara permanen...${NC}"
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1
    echo -e " - Tersimpan menggunakan netfilter-persistent"
else
    # Fallback jika pakai iptables-persistent biasa
    iptables-save > /etc/iptables/rules.v4
    echo -e " - Tersimpan di /etc/iptables/rules.v4"
fi

# 4. Ambil Token dan Chat ID Telegram
echo -e "${GREEN}[*] Mengumpulkan data untuk Telegram...${NC}"
BOT_TOKEN=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | awk '{print $2}')
CHAT_ID=$(grep -E "^#bot# " "/etc/bot/.bot.db" 2>/dev/null | awk '{print $3}')
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || curl -s ipv4.icanhazip.com 2>/dev/null)

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo -e "\n⚠️ Gagal mengirim ke Telegram: Token atau Chat ID tidak ditemukan di /etc/bot/.bot.db"
    exit 1
fi

# 5. Rekap hasil iptables terbaru
IPTABLES_OUT=$(iptables -t nat -L PREROUTING -n --line-numbers)

# Format Pesan Telegram
TEXT="🛠 <b>IPTABLES NAT REPAIRED</b> 🛠
🌐 <b>Server:</b> <code>${DOMAIN}</code>
⏰ <b>Waktu:</b> <code>$(date +'%Y-%m-%d %H:%M:%S')</code>

<b>Status PREROUTING Saat Ini:</b>
<pre>${IPTABLES_OUT}</pre>"

# 6. Kirim Laporan ke Bot Telegram
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${TEXT}" \
    -d "parse_mode=HTML" >/dev/null 2>&1

echo -e "${GREEN}[*] Laporan berhasil dikirim ke Telegram!${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "Selesai. Iptables Anda sekarang sudah sehat & kebal reboot."