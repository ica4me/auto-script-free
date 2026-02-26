# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

# Menghindari pesan error "mesg: ttyname failed"
mesg n || true

# Menjalankan Welcome Dashboard sebagai Banner Login
if command -v welcome >/dev/null 2>&1; then
    welcome
else
    # Fallback jika skrip welcome tidak ditemukan
    clear
    echo -e "\033[1;31m"
    echo "╔══════════════════════════════════════════╗"
    echo "║ [!] Skrip 'welcome' tidak ditemukan!     ║"
    echo "║     Ketik 'menu' untuk membuka panel.    ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "\033[0m"
fi