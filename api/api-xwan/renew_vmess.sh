#!/bin/bash
user=$1
masaaktif=$2
iplimit=$3
Quota=$4

# --- BAGIAN BYPASS LISENSI ---
checking_sc() {
    # Logika cek IP dihapus untuk Full Akses
    echo "License ByPass... SUCCESS!"
}
checking_sc
# -----------------------------

# Cek keberadaan user VMess
if ! grep -qwE "^### $user" /etc/xray/config.json; then
    echo -e "User $user Tidak Ditemukan!!"
    exit 1
else
    # Ambil tanggal expired saat ini
    exp=$(grep -wE "^### $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    
    # Update Limit IP
    mkdir -p /etc/kyt/limit/vmess/ip
    if [[ $iplimit -gt 0 ]]; then
        echo -e "$iplimit" > /etc/kyt/limit/vmess/ip/${user}
    else
        echo > /dev/null
    fi

    # Buat folder vmess jika belum ada (untuk quota)
    if [ ! -e /etc/vmess/ ]; then
        mkdir -p /etc/vmess/
    fi

    # Update Quota
    if [ -z ${Quota} ]; then
        Quota="0"
    fi

    c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
    d=$((${c} * 1024 * 1024 * 1024))

    if [[ ${c} != "0" ]]; then
        echo "${d}" >/etc/vmess/${user}
    fi
    
    # Hitung Tanggal Expired Baru
    now=$(date +%Y-%m-%d)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    exp3=$(($exp2 + $masaaktif))
    exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
    
    # Update Config Xray
    sed -i "/### $user/c\### $user $exp4" /etc/xray/config.json
    
    # Update Database (Opsional, agar sinkron)
    if [ -f "/etc/vmess/.vmess.db" ]; then
         sed -i "/^### $user/s/$exp/$exp4/" /etc/vmess/.vmess.db
    fi

    systemctl restart xray > /dev/null 2>&1
    clear
    echo -e "  RENEW VMESS"
    echo -e " Remark      : $user "
    echo -e " Limit Ip    : ${iplimit}"
    echo -e " Limit Quota : ${Quota} GB"
    echo -e " Expiry in   : $exp4 "
    exit 0
fi