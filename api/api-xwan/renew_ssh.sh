#!/bin/bash
# clear # Komentari atau hapus ini

User=$1
Days=$3
iplimit=$2

# --- BAGIAN BYPASS LISENSI ---
checking_sc() {
    # Logika cek IP dihapus untuk Full Akses
    # Langsung return 0 (Sukses)
    return 0
}
checking_sc
# -----------------------------

# Cek apakah user ada
if id "$User" &>/dev/null; then
  # Ambil masa aktif saat ini
  current_exp=$(chage -l $User | grep "Account expires" | cut -d: -f2 | xargs)

  # Hitung tanggal dasar (hari ini atau tanggal expired sebelumnya)
  if [[ "$current_exp" == "never" ]] || [[ -z "$current_exp" ]]; then
    base_date=$(date +%s)
  else
    base_date=$(date -d "$current_exp" +%s)
  fi

  # Hitung tanggal expired baru
  Days_Detailed=$(( $Days * 86400 ))
  Expire_On=$(( $base_date + $Days_Detailed ))
  Expiration=$(date -u --date="1970-01-01 $Expire_On sec GMT" +%Y/%m/%d)
  Expiration_Display=$(date -u --date="1970-01-01 $Expire_On sec GMT" '+%d %b %Y')
  
  # Update database internal script (jika ada)
  if [ -f "/etc/xray/ssh" ]; then
      expi=$(grep -wE "$User" /etc/xray/ssh | cut -d " " -f6-8)
      if [[ -n "$expi" ]]; then
          sed -i "s/$expi/$Expiration_Display/" /etc/xray/ssh
      fi
  fi
  
  # Update masa aktif user sistem
  passwd -u $User &>/dev/null 
  usermod -e $Expiration $User &>/dev/null

  # Output dalam format Key : Value
  echo "Remark      : ${User}"
  echo "Limit Ip    : ${iplimit}"
  echo "Expiry in   : ${Expiration_Display}"
  exit 0
else
  echo "RENEW SSH GAGAL: User tidak ditemukan" # Output teks error
  exit 1
fi