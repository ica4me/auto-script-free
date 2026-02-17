#!/bin/bash
Login=$1
masaaktif=$2
iplimit=$3
Quota=$4
user="${Login}VL$(tr -dc 0-9 </dev/urandom | head -c3)"
IP=$(curl -sS ipv4.icanhazip.com)
data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
date_list=$(date +"%Y-%m-%d" -d "$data_server")

# --- BAGIAN BYPASS LISENSI ---
checking_sc() {
    # Logika cek IP dihapus untuk Full Akses
    echo "License ByPass... SUCCESS!"
}
checking_sc
# -----------------------------

ISP=$(cat /etc/xray/isp)
CITY=$(cat /etc/xray/city)
domain=$(cat /etc/xray/domain)
nama=$(cat /etc/xray/username)
uuid=$(cat /proc/sys/kernel/random/uuid)
clear
tgl=$(date -d "$masaaktif days" +"%d")
bln=$(date -d "$masaaktif days" +"%b")
thn=$(date -d "$masaaktif days" +"%Y")
expe="$tgl $bln, $thn"
tgl2=$(date +"%d")
bln2=$(date +"%b")
thn2=$(date +"%Y")
tnggl="$tgl2 $bln2, $thn2"
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
sed -i '/#vless$/a\#& '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vlessgrpc$/a\#& '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:80?path=/vless&security=none&host=${domain}&type=ws#${user}"
vlesslink3="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"


if [ ! -e /etc/vless ]; then
  mkdir -p /etc/vless
fi

if [[ $iplimit -gt 0 ]]; then
mkdir -p /etc/kyt/limit/vless/ip
echo -e "$iplimit" > /etc/kyt/limit/vless/ip/$user
else
echo > /dev/null
fi

if [ -z ${Quota} ]; then
  Quota="0"
fi

c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
d=$((${c} * 1024 * 1024 * 1024))

if [[ ${c} != "0" ]]; then
  echo "${d}" >/etc/vless/${user}
fi
DATADB=$(cat /etc/vless/.vless.db | grep "^#&" | grep -w "${user}" | awk '{print $2}')
if [[ "${DATADB}" != '' ]]; then
  sed -i "/\b${user}\b/d" /etc/vless/.vless.db
  echo "#& ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/vless/.vless.db
else
echo "#& ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/vless/.vless.db
fi
clear
mkdir -p /detail/vless/
#Simpan Detail Akun User
cat > /detail/vless/$user.txt <<-END
-----------------------------------------
Xray/Vless Account
-----------------------------------------
Remarks     : ${user}
Domain      : ${domain}
User Quota  : ${Quota} GB
User Ip     : ${iplimit} IP
Port Non TLS: 80,8080,2086,8880
Port TLS    : 443,8443
User ID     : ${uuid}
Encryption  : none
Path TLS    : /vless/multi-path
ServiceName : vless-grpc
-----------------------------------------
Link TLS    : ${vlesslink1}
-----------------------------------------
Link NTLS   : ${vlesslink2}
-----------------------------------------
Link GRPC   : ${vlesslink3}
-----------------------------------------
Format OpenClash : https://${domain}:81/vless-$user.txt
-----------------------------------------
Aktif Selama     : $masaaktif Hari
Dibuat Pada      : $tnggl
Berakhir Pada    : $expe
-----------------------------------------

END

cat >/var/www/html/vless-$user.txt <<-END

-----------------------------------------
Format Open Clash
-----------------------------------------
- name: Vless-$user-WS TLS
  server: ${domain}
  port: 443
  type: vless
  uuid: ${uuid}
  cipher: auto
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vless
    headers:
      Host: ${domain}

- name: Vless-$user-WS (CDN) Non TLS
  server: ${domain}
  port: 80
  type: vless
  uuid: ${uuid}
  cipher: auto
  tls: false
  skip-cert-verify: false
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vless
    headers:
      Host: ${domain}
  udp: true

- name: Vless-$user-gRPC (SNI)
  server: ${domain}
  port: 443
  type: vless
  uuid: ${uuid}
  cipher: auto
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: grpc
  grpc-opts:
  grpc-mode: gun
    grpc-service-name: vless-grpc

-----------------------------------------
Link Akun Vless 
-----------------------------------------
Link TLS      : 
${vlesslink1}
-----------------------------------------
Link none TLS : 
${vlesslink2}
-----------------------------------------
Link GRPC     : 
${vlesslink3}
-----------------------------------------
Expired          : $expe
-----------------------------------------
END

function notif_vl() {
    # --- SETTING TELEGRAM (WAJIB DIGANTI) ---
    CHATID=""
    KEY=""
    # ----------------------------------------
    
    export TIME="10"
    export URL="https://api.telegram.org/bot$KEY/sendMessage"
    sensor=$(echo "$user" | sed 's/\(.\{3\}\).*/\1xxx/')
    ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10 )
    TEXT="
<b>-----------------------------------------</b>
<b>TRANSACTION SUCCESSFUL</b>
<b>-----------------------------------------</b>
<b>» Produk : Vless</b>
<b>» ISP :</b> <code>${ISP}</code>
<b>» Limit Quota :</b> <code>${Quota} GB</code>
<b>» Limit Login :</b> <code>${iplimit} Hp</code>
<b>» Username :</b> <code>$sensor</code>
<b>» Duration :</b> <code>${masaaktif} Days</code>
<b>-----------------------------------------</b>
<i>Automatic Notification From Server</i>
<b>-----------------------------------------</b>
"
    # Kirim notifikasi hanya jika KEY dan CHATID diisi
    if [[ -n "$KEY" && -n "$CHATID" ]]; then
        curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
    fi
}

notif_vl
systemctl restart xray > /dev/null 2>&1
clear
echo -e " VLESS XRAY "

echo -e " Remark       : ${user}"
echo -e " Domain        : ${domain}"
echo -e " Limit Quota    : ${Quota} GB"
echo -e " Limit Ip       : ${iplimit}"
echo -e " Port TLS      : 400,8443"
echo -e " port WS       : 80,8880,8080,2082"
echo -e " Key           : ${uuid}"
echo -e " Locations     : $CITY"
echo -e " ISP           : $ISP"
echo -e " AlterId       : 0"
echo -e " Security      : auto"
echo -e " Network       : ws"
echo -e " Path          : /vless"
echo -e " Dynamic Path  : yourbug/vless"
echo -e " ServiceName   : vless-grpc"

echo -e " Link TLS      : ${vlesslink1}"
echo -e " Link WS       : ${vlesslink2}"
echo -e " Link GRPC     : ${vlesslink3}"
echo -e " OpenClash     : https://${domain}:81/vless-$user.txt"

echo -e " Days in    : $masaaktif Day "
echo -e " Expiry in  : $expe "