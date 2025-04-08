#!/bin/bash

# Çıktı için renkler
NC='\e[0m'       # Renksiz (metin rengini varsayılana sıfırlar)
DEFBOLD='\e[39;1m' # Varsayılan Kalın
RB='\e[31;1m'    # Kırmızı Kalın
GB='\e[32;1m'    # Yeşil Kalın
YB='\e[33;1m'    # Sarı Kalın
BB='\e[34;1m'    # Mavi Kalın
MB='\e[35;1m'    # Magenta Kalın
CB='\e[36;1m'    # Cyan Kalın
WB='\e[37;1m'    # Beyaz Kalın

clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#&@ " "/usr/local/etc/xray/config/04_inbounds.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "               ${WB}Xray Hesabı Süresini Uzat${NC}              "
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "  ${YB}Herhangi bir istemci bulunamadı!${NC}"
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo ""
    read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın"
    allxray
fi

clear
echo -e "${BB}————————————————————————————————————————————————————${NC}"
echo -e "               ${WB}Xray Hesabı Süresini Uzat${NC}              "
echo -e "${BB}————————————————————————————————————————————————————${NC}"
echo -e " ${YB}Kullanıcı Adı      Bitiş Tarihi${NC}  "
echo -e "${BB}————————————————————————————————————————————————————${NC}"
grep -E "^#&@ " "/usr/local/etc/xray/config/04_inbounds.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq
echo ""
echo -e "${YB}Ana menüye dönmek için enter'a basın${NC}"
echo -e "${BB}————————————————————————————————————————————————————${NC}"
read -rp "Kullanıcı Adı Girin: " user
if [ -z $user ]; then
    allxray
else
    read -p "Uzatılacak Süre (gün): " masaaktif
    exp=$(grep -wE "^#&@ $user" "/usr/local/etc/xray/config/04_inbounds.json" | cut -d ' ' -f 3 | sort | uniq)
    now=$(date +%Y-%m-%d)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    exp3=$(($exp2 + $masaaktif))
    exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
    sed -i "/#&@ $user/c\#&@ $user $exp4" /usr/local/etc/xray/config/04_inbounds.json
    systemctl restart xray
    clear
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "          ${WB}Xray Hesabı Süresi Başarıyla Uzatıldı${NC}         "
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e " ${YB}Kullanıcı Adı   :${NC} $user"
    echo -e " ${YB}Bitiş Tarihi    :${NC} $exp4"
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo ""
    read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın"
    clear
    allxray
fi
