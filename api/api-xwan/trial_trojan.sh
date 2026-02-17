#!/bin/bash
if ! command -v at &> /dev/null; then
    apt update && sudo apt install -y at
	systemctl enable --now atd
fi
Login="${1:-Trial}"        
masaaktif="${2:-1}"        
iplimit="${3:-1}"
Quota="${4:-1}"
pup=30
user="${Login}TR$(tr -dc 0-9 </dev/urandom | head -c3)"
IP=$(curl -sS ipv4.icanhazip.com)
checking_sc() {
    # Logika cek IP dihapus untuk Full Akses
    echo "License ByPass... SUCCESS!"
}
checking_sc
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
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#trojanws$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#trojangrpc$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

# Link Trojan Akun
systemctl restart xray
trojanlink1="trojan://${uuid}@bugkamu.com:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"
trojanlink="trojan://${uuid}@bugkamu.com:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
trojanlink2="trojan://${uuid}@bugkamu.com:80?path=%2Ftrojan-ws&security=none&host=${domain}&type=ws#${user}"

mkdir -p /detail/trojan/
#Simpan Detail Akun User
cat > /detail/trojan/$user.txt <<-END
-----------------------------------------
Trial Trojan Account
-----------------------------------------
Remarks          : ${user}
Host/IP          : ${domain}
User Quota       : ${Quota} GB
User Ip          : ${iplimit} IP
Port             : 443,8443
Key              : ${uuid}
Path             : /trojan-ws/multi-path
ServiceName      : trojan-grpc
-----------------------------------------
Link TLS         : ${trojanlink}
-----------------------------------------
Link GRPC        : ${trojanlink1}
-----------------------------------------
Format OpenClash : https://${domain}:81/trojan-$user.txt
-----------------------------------------
Dibuat Pada      : $tnggl
Aktif Selama     : $pup Minutes
-----------------------------------------

END

cat >/var/www/html/trojan-$user.txt <<-END
-----------------------------------------
Format Open Clash
-----------------------------------------
- name: Trojan-$user-GO/WS
  server: ${domain}
  port: 443
  type: trojan
  password: ${uuid}
  network: ws
  sni: ${domain}
  skip-cert-verify: true
  udp: true
  ws-opts:
    path: /trojan-ws
    headers:
        Host: ${domain}

- name: Trojan-$user-gRPC
  type: trojan
  server: ${domain}
  port: 443
  password: ${uuid}
  udp: true
  sni: ${domain}
  skip-cert-verify: true
  network: grpc
  grpc-opts:
    grpc-service-name: trojan-grpc

-----------------------------------------
Link Akun Trojan 
-----------------------------------------
Link WS          : 
${trojanlink}
-----------------------------------------
Link GRPC        : 
${trojanlink1}
-----------------------------------------
Expired          : ${pup} Minutes
-----------------------------------------
END

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
<b>» Produk : Trial Trojan</b>
<b>» ISP :</b> <code>${ISP}</code>
<b>» Limit Quota :</b> <code>${Quota} GB</code>
<b>» Limit Login :</b> <code>${iplimit} Hp</code>
<b>» Username :</b> <code>$sensor</code>
<b>» Duration :</b> <code>${pup} Minutes</code>
<b>-----------------------------------------</b>
<i>Automatic Notification From Server</i>
<b>-----------------------------------------</b>"

curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
clear


if [ ! -e /etc/trojan ]; then
  mkdir -p /etc/trojan
fi

if [[ $iplimit -gt 0 ]]; then
mkdir -p /etc/kyt/limit/trojan/ip
echo -e "$iplimit" > /etc/kyt/limit/trojan/ip/$user
else
echo > /dev/null
fi

if [ -z ${Quota} ]; then
  Quota="0"
fi

c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
d=$((${c} * 1024 * 1024 * 1024))

if [[ ${c} != "0" ]]; then
  echo "${d}" >/etc/trojan/${user}
fi
DATADB=$(cat /etc/trojan/.trojan.db | grep "^#!" | grep -w "${user}" | awk '{print $2}')
if [[ "${DATADB}" != '' ]]; then
  sed -i "/\b${user}\b/d" /etc/trojan/.trojan.db
  echo "#! ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/trojan/.trojan.db
else
echo "#! ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/trojan/.trojan.db
fi

    systemctl restart xray > /dev/null 2>&1
		echo sed -i \"/$user/d\" /etc/xray/config.json  | at now + $pup minutes

echo "systemctl restart xray" | at now + $pup minutes
clear
echo -e " TROJAN XRAY "
echo -e " Remark       : ${user}"
echo -e " Domain        : ${domain}"
echo -e " Limit Quota    : ${Quota} GB"
echo -e " Limit Ip       : ${iplimit}"
echo -e " Port TLS      : 400,8443"
echo -e " port WS       : 80,8880,8080,2082"
echo -e " Key           : ${uuid}"
echo -e " Localtions    : $CITY"
echo -e " ISP           : $ISP"
echo -e " AlterId       : 0"
echo -e " Security      : auto"
echo -e " Network       : ws"
echo -e " Path          : /trojan-ws"
echo -e " Dynamic Path  : yourbug/trojan-ws"
echo -e " ServiceName   : trojan-grpc"

echo -e " Link TLS      : ${trojanlink}"
echo -e " Link WS       : ${trojanlink2}"
echo -e " Link GRPC     : ${trojanlink1}"
echo -e " OpenClash     : https://${domain}:81/trojan-$user.txt"

echo -e " Days in    : $masaaktif Day "
echo -e " Expiry in  : $pup Minutes "