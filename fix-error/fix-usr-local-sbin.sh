#!/bin/bash
# ==========================================
# Script Fix CRLF to LF (Windows to Linux Format)
# Target: /usr/local/sbin/*
# OS Support: Debian & Ubuntu Family
# ==========================================

# Warna untuk output terminal
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}      FIX DOS2UNIX /USR/LOCAL/SBIN        ${NC}"
echo -e "${CYAN}==========================================${NC}"

# 1. Pengecekan Akses Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Script ini harus dijalankan sebagai root!${NC}"
  echo -e "Gunakan perintah: sudo bash $0"
  exit 1
fi

# 2. Pengecekan OS (Keluarga Debian/Ubuntu)
if [ ! -f /etc/debian_version ]; then
  echo -e "${RED}[ERROR] OS Tidak Didukung!${NC}"
  echo -e "Script ini hanya untuk keluarga Debian/Ubuntu."
  exit 1
fi

# 3. Pengecekan & Instalasi dos2unix
echo -e "[ ${YELLOW}INFO${NC} ] Mengecek paket dos2unix..."
if ! command -v dos2unix >/dev/null 2>&1; then
    echo -e "[ ${YELLOW}WAIT${NC} ] dos2unix belum terinstall. Memulai instalasi..."
    
    # Update repository secara diam-diam (quiet)
    apt-get update -yq >/dev/null 2>&1
    
    # Install dos2unix
    apt-get install dos2unix -yq >/dev/null 2>&1
    
    # Verifikasi ulang setelah instalasi
    if ! command -v dos2unix >/dev/null 2>&1; then
        echo -e "[ ${RED}FAIL${NC} ] Gagal menginstall dos2unix. Cek koneksi internet atau repository Anda."
        exit 1
    fi
    echo -e "[ ${GREEN}DONE${NC} ] dos2unix berhasil diinstall!"
else
    echo -e "[ ${GREEN}OK${NC} ] Paket dos2unix sudah tersedia."
fi

echo -e "------------------------------------------"
echo -e "[ ${YELLOW}INFO${NC} ] Memulai pemindaian dan perbaikan file..."
sleep 1

# 4. Eksekusi dos2unix pada direktori target
# dos2unix sangat aman karena otomatis melewati (skip) file binary dan direktori.
dos2unix /usr/local/sbin/*

echo -e "------------------------------------------"
echo -e "[ ${GREEN}SUKSES${NC} ] Seluruh script di /usr/local/sbin/ telah distandarisasi ke format Linux (LF)."
echo -e "File binary (aplikasi) secara otomatis diabaikan agar tidak rusak."
echo -e "${CYAN}==========================================${NC}"