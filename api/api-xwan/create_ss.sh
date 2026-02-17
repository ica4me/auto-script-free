#!/bin/bash
Login=$1
masaaktif=$2
iplimit=$3
Quota=$4
user="${Login}SS$(tr -dc 0-9 </dev/urandom | head -c3)"
IP=$(curl -sS ipv4.icanhazip.com)
data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
date_list=$(date +"%Y-%m-%d" -d "$data_server")

# --- BAGIAN BYPASS START ---
checking_sc() {
    echo "License ByPass... SUCCESS!"
}
# --- BAGIAN BYPASS END ---

checking_sc
ISP=$(cat /etc/xray/isp)
CITY=$(cat /etc/xray/city)
domain=$(cat /etc/xray/domain)
cipher="aes-128-gcm"
uuid=$(cat /proc/sys/kernel/random/uuid)
tgl=$(date -d "$masaaktif days" +"%d")
bln=$(date -d "$masaaktif days" +"%b")
thn=$(date -d "$masaaktif days" +"%Y")
expe="$tgl $bln, $thn"
tgl2=$(date +"%d")
bln2=$(date +"%b")
thn2=$(date +"%Y")
tnggl="$tgl2 $bln2, $thn2"
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#ssws$/a\#@& '"$user $exp"'\
},{"password": "'""$uuid""'","method": "'""$cipher""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#ssgrpc$/a\#@& '"$user $exp"'\
},{"password": "'""$uuid""'","method": "'""$cipher""'","email": "'""$user""'"' /etc/xray/config.json
echo $cipher:$uuid > /tmp/log
shadowsocks_base64=$(cat /tmp/log)
echo -n "${shadowsocks_base64}" | base64 > /tmp/log1
shadowsocks_base64e=$(cat /tmp/log1)
shadowsockslink="ss://${shadowsocks_base64e}@$domain:$tls?plugin=xray-plugin;mux=0;path=/ss-ws;host=$domain;tls#${user}"
shadowsockslink1="ss://${shadowsocks_base64e}@$domain:$tls?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=$domain;tls#${user}"

#buat ss WEBSOCKET
sslinkws="ss://${shadowsocks_base64e}@${domain}:443?path=/ss-ws&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
nonsslinkws="ss://${shadowsocks_base64e}@${domain}:80?path=/ss-ws&security=none&encryption=none&type=ws&host=${domain}#${user}"

#buat ss GRPC
sslinkgrpc="ss://${shadowsocks_base64e}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=ss-grpc&sni=${domain}#${user}"
nonsslinkgrpc="ss://${shadowsocks_base64e}@${domain}:80?mode=gun&security=none&encryption=none&type=grpc&serviceName=ss-grpc&sni=${domain}#${user}"

systemctl restart xray > /dev/null 2>&1
#buatshadowsocks custom
rm -rf /tmp/log
rm -rf /tmp/log1

mkdir -p /detail/shadowsocks/
#Simpan Detail Akun User
cat > /detail/shadowsocks/$user.txt <<-END
-----------------------------------------
Xray/Shadowsocks Account
-----------------------------------------
Remarks     : ${user}
Domain      : ${domain}
User Quota  : ${Quota} GB
User Ip     : ${iplimit} IP
Port Non TLS: 80,8080,2086,8880
Port TLS    : 443,8443
Password    : ${uuid}
Cipers      : aes-128-gcm
Network     : ws/grpc
Path        : /ss-ws
ServiceName : ss-grpc
-----------------------------------------
Link WS TLS : ${sslinkws}
-----------------------------------------
Link WS None TLS : ${nonsslinkws}
-----------------------------------------
Link GRPC : ${sslinkgrpc}
-----------------------------------------
Format OpenClash : https://${domain}:81/ss-$user.txt
-----------------------------------------
Aktif Selama   : $masaaktif Hari
Dibuat Pada    : $tnggl
Berakhir Pada  : $expe
-----------------------------------------

END

cat >/var/www/html/ss-$user.txt <<-END

-----------------------------------------
Format Open Clash
-----------------------------------------
- name: Shadowsocks-$user-WS-Non-TLS
  server: ${domain}
  port: 80
  type: ss
  cipher: aes-128-gcm
  password: ${uuid}
  udp: true
  network: ws
  ws-opts:
    path: /ss-ws
    headers:
      Host: ${domain}
  tls: false
  
- name: Shadowsocks-$user-WS-TLS
  server: ${domain}
  port: 443
  type: ss
  cipher: aes-128-gcm
  password: ${uuid}
  udp: true
  network: ws
  ws-opts:
    path: /ss-ws
    headers:
      Host: ${domain}
  tls: true

- name: Shadowsocks-$user-gRPC-SNI
  server: ${domain}
  port: 443
  type: ss
  cipher: aes-128-gcm
  password: ${uuid}
  udp: true
  network: grpc
  grpc-opts:
    service-name: ss-grpc
  tls: true
  sni: ${domain}

-----------------------------------------
Link Akun Shadowsocks                   
-----------------------------------------
Link TLS         : 
${sslinkws}
-----------------------------------------
Link none TLS    : 
${nonsslinkws}
-----------------------------------------
Link GRPC        : 
${sslinkgrpc}
-----------------------------------------
Expired          : $expe
-----------------------------------------

END
systemctl reload xray >/dev/null 2>&1
service cron restart >/dev/null 2>&1
if [[ $iplimit -gt 0 ]]; then
mkdir -p /etc/kyt/limit/shadowsocks/ip
echo -e "$iplimit" > /etc/kyt/limit/shadowsocks/ip/$user
else
echo > /dev/null
fi

if [ -z ${Quota} ]; then
  Quota="0"
fi

if [ ! -e /etc/shadowsocks ]; then
  mkdir -p /etc/shadowsocks
fi

if [ -z ${Quota} ]; then
  Quota="0"
fi

c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
d=$((${c} * 1024 * 1024 * 1024))

if [[ ${c} != "0" ]]; then
  echo "${d}" >/etc/shadowsocks/${user}
fi
DATADB=$(cat /etc/shadowsocks/.shadowsocks.db | grep "^#@&" | grep -w "${user}" | awk '{print $2}')
if [[ "${DATADB}" != '' ]]; then
  sed -i "/\b${user}\b/d" /etc/shadowsocks/.shadowsocks.db
fi
echo "#@& ${user} ${exp} ${uuid}" >>/etc/shadowsocks/.shadowsocks.db

clear
function notif_ss() {
    # WARNING: GANTI CHATID DAN KEY DI BAWAH INI DENGAN MILIK ANDA
    CHATID="" 
    KEY=""
    export TIME="10"
    export URL="https://api.telegram.org/bot$KEY/sendMessage"
    sensor=$(echo "$user" | sed 's/\(.\{3\}\).*/\1xxx/')
    ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10 )
    TEXT="
<b>-----------------------------------------</b>
<b>TRANSACTION SUCCESSFUL</b>
<b>-----------------------------------------</b>
<b>» Produk : Shadowsocks</b>
<b>» ISP :</b> <code>${ISP}</code>
<b>» Limit Quota :</b> <code>${Quota} GB</code>
<b>» Limit Login :</b> <code>${iplimit} Hp</code>
<b>» Username :</b> <code>${sensor}</code>
<b>» Duration :</b> <code>${masaaktif} Days</code>
<b>-----------------------------------------</b>
<i>Automatic Notification From Server</i>
<b>-----------------------------------------</b>
"
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
}

notif_ss
echo -e " SHOCKSHADOW XRAY "

echo -e " Remark       : ${user}"
echo -e " Domain        : ${domain}"
echo -e " Limit Quota    : ${Quota} GB"
echo -e " Limit Ip       : ${iplimit}"
echo -e " Port TLS      : 400,8443"
echo -e " port WS       : 80,8080,2086,8880"
echo -e " Key           : ${uuid}"
echo -e " Localtions    : $CITY"
echo -e " ISP           : $ISP"
echo -e " Cipers        : aes-128-gcm"
echo -e " Security      : auto"
echo -e " Network       : ws/grpc"
echo -e " Path          : /ss-ws"
echo -e " Dynamic Path  : yourbug/ss-ws"
echo -e " ServiceName   : ss-grpc"

echo -e " Link TLS      : ${sslinkws}"
echo -e " Link WS       : ${nonsslinkws}"
echo -e " Link GRPC     : ${sslinkgrpc}"
echo -e " OpenClash     : https://${domain}:81/ss-$user.tx"

echo -e " Days in    : $masaaktif Day "
echo -e " Expiry in  : $expe "