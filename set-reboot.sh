cat > /usr/local/bin/setup_reboot.sh << 'EOF'
#!/bin/bash

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}[PROCESS] Memulai modifikasi perintah reboot...${NC}"

# 1. Deteksi lokasi asli binary reboot
# Kita cari file binary asli agar 'rebootya' nanti memanggil file yang benar
if [ -f "/usr/sbin/reboot" ]; then
    REAL_REBOOT="/usr/sbin/reboot"
elif [ -f "/sbin/reboot" ]; then
    REAL_REBOOT="/sbin/reboot"
else
    # Fallback jika tidak ketemu, gunakan systemctl
    REAL_REBOOT="systemctl reboot"
fi

echo -e "${GREEN}[INFO] Path reboot asli ditemukan di: $REAL_REBOOT${NC}"

# 2. Buat perintah 'rebootya' (Perintah Asli yang Baru)
# Ini ditaruh di /usr/bin agar bisa diakses global
cat > /usr/bin/rebootya <<END
#!/bin/bash
echo -e "${GREEN}[SYSTEM] Melakukan Restart VPS...${NC}"
$REAL_REBOOT
END

# Berikan izin eksekusi
chmod +x /usr/bin/rebootya
echo -e "${GREEN}[OK] Perintah 'rebootya' berhasil dibuat.${NC}"

# 3. Buat perintah 'reboot' Palsu (Blocker)
# Ditaruh di /usr/local/bin karena prioritasnya lebih tinggi dari /usr/sbin
cat > /usr/local/bin/reboot <<END
#!/bin/bash
echo -e "${RED}=========================================${NC}"
echo -e "${RED}[AKSES DITOLAK] Perintah 'reboot' DIMATIKAN!${NC}"
echo -e "${YELLOW}Untuk keamanan sistem, silahkan gunakan perintah:${NC}"
echo -e "${GREEN}rebootya${NC}"
echo -e "${RED}=========================================${NC}"
END

# Berikan izin eksekusi
chmod +x /usr/local/bin/reboot
echo -e "${GREEN}[OK] Proteksi perintah 'reboot' berhasil dipasang.${NC}"

# 4. Refresh Hash Shell
# Agar terminal langsung mengenali perubahan tanpa perlu login ulang
hash -r

echo -e ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}       MODIFIKASI SELESAI & SUKSES!           ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo -e "Silahkan coba ketik: ${RED}reboot${NC} (Harusnya gagal)"
echo -e "Lalu ketik: ${GREEN}rebootya${NC} (Untuk restart beneran)"
EOF

# Jalankan scriptnya langsung
chmod +x /usr/local/bin/setup_reboot.sh
/usr/local/bin/setup_reboot.sh