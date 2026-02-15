# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

# Menghindari pesan error "mesg: ttyname failed"
mesg n || true

# Bersihkan layar terminal
clear

# Menjalankan Neofetch sebagai Banner
# Script akan mengecek apakah neofetch ada, jika ada akan dijalankan.
if command -v neofetch >/dev/null 2>&1; then
    neofetch
else
    # Fallback jika neofetch belum diinstall
    echo -e "\033[1;36m"
    echo "╔══════════════════════════════════════════╗"
    echo "║     Silahkan install neofetch:           ║"
    echo "║     apt update && apt install neofetch   ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "\033[0m"
fi