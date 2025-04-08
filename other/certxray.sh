NC='\e[0m'
DEFBOLD='\e[39;1m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'
BB='\e[34;1m'
MB='\e[35;1m'
CB='\e[35;1m'
WB='\e[37;1m'
clear
echo -e "${GB}[ BİLGİ ]${NC} ${YB}Başlatılıyor${NC} "
sleep 0.5
systemctl stop nginx
domain=$(cat /var/lib/dnsvps.conf | cut -d'=' -f2)
Cek=$(lsof -i:80 | cut -d' ' -f1 | awk 'NR==2 {print $1}')
if [[ ! -z "$Cek" ]]; then
sleep 1
echo -e "${RB}[ UYARI ]${NC} ${YB}80 portunu $Cek tarafından kullanıldığı tespit edildi${NC} "
systemctl stop $Cek
sleep 2
echo -e "${GB}[ BİLGİ ]${NC} ${YB}$Cek durdurma işlemi sürüyor${NC} "
sleep 1
fi
echo -e "${GB}[ BİLGİ ]${NC} ${YB}Sertifika yenileme başlatılıyor...${NC} "
sleep 2
export CF_Email="guzelim.batmanli@gmail.com"
export CF_Key="4aa140cf85fde3adadad1856bdf67cf5ad460"
bash .acme.sh/acme.sh --issue --dns dns_cf -d $domain -d *.$domain --listen-v6 --server letsencrypt --keylength ec-256 --fullchain-file /usr/local/etc/xray/fullchain.cer --key-file /usr/local/etc/xray/private.key --reloadcmd "systemctl restart nginx" --force
chmod 745 /usr/local/etc/xray/private.key
echo -e "${GB}[ BİLGİ ]${NC} ${YB}Sertifika yenileme tamamlandı...${NC} "
sleep 2
echo -e "${GB}[ BİLGİ ]${NC} ${YB}$Cek servisi başlatılıyor${NC} "
sleep 2
echo "$domain" > /usr/local/etc/xray/dns/domain
systemctl restart $Cek
systemctl restart nginx
echo -e "${GB}[ BİLGİ ]${NC} ${YB}Tüm işlemler tamamlandı...${NC} "
sleep 0.5
echo ""
read -n 1 -s -r -p "Menüye dönmek için herhangi bir tuşa basın"
menu
