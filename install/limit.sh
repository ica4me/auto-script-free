REPO="https://raw.githubusercontent.com/ica4me/auto-script-free/main/"

# ------------------------------------------
# Prepare systemd dan direktori kerja
# ------------------------------------------
cd
systemctl daemon-reload

# ------------------------------------------
# Download systemd service untuk limit klasik
# ------------------------------------------
echo "[INFO] Mengunduh file systemd service versi lama..."
wget -q -O /etc/systemd/system/limitvmess.service "${REPO}install/limitvmess.service" && chmod +x /etc/systemd/system/limitvmess.service
wget -q -O /etc/systemd/system/limitvless.service "${REPO}install/limitvless.service" && chmod +x /etc/systemd/system/limitvless.service
wget -q -O /etc/systemd/system/limittrojan.service "${REPO}install/limittrojan.service" && chmod +x /etc/systemd/system/limittrojan.service

# Jika mau aktifkan Shadowsocks
wget -q -O /etc/systemd/system/limitshadowsocks.service "${REPO}install/limitshadowsocks.service" && chmod +x /etc/systemd/system/limitshadowsocks.service

# ------------------------------------------
# Reload daemon dan enable service lama
# ------------------------------------------
echo "[INFO] Reload systemd daemon..."
systemctl daemon-reload

echo "[INFO] Enable & start classic services..."
systemctl enable --now limitvmess
systemctl enable --now limitvless
systemctl enable --now limittrojan
# systemctl enable --now limitshadowsocks

# ------------------------------------------
# Start service klasik (jika belum jalan)
# ------------------------------------------
systemctl start limitvmess
systemctl start limitvless
systemctl start limittrojan
# systemctl start limitshadowsocks

echo -e "\033[1;32m[SUCCESS]\033[0m Semua limit service klasik berhasil diaktifkan!"
echo

# function limit-ip(){
# echo "[INFO] Menambahkan versi systemd-template (limit-ip@)..."
# rm -rf /usr/local/sbin/limit-ip
#
# # MENCEGAH DOWNLOAD FILE BINER BERBAHAYA
# # wget -q -O /usr/local/sbin/unlockxray "${REPO}install/unlockxray" && chmod +x /usr/local/sbin/unlockxray
# # wget -q -O /usr/local/sbin/limit-ip "${REPO}install/limit-ip" && chmod +x /usr/local/sbin/limit-ip
#
# echo -e "\033[1;33m[BYPASS]\033[0m Pemasangan limit-ip@ timer dibatalkan demi keamanan."
# }

# limit-ip

exit 0