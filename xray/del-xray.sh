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
    clear
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "              ${WB}Xray Hesabı Sil${NC}               "
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "  ${YB}Herhangi bir istemci bulunamadı!${NC}"
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın"
    allxray
fi

clear
echo -e "${BB}————————————————————————————————————————————————————${NC}"
echo -e "              ${WB}Xray Hesabı Sil${NC}               "
echo -e "${BB}————————————————————————————————————————————————————${NC}"
echo -e " ${YB}Kullanıcı Adı      Bitiş Tarihi${NC}  "
echo -e "${BB}————————————————————————————————————————————————————${NC}"
grep -E "^#&@ " "/usr/local/etc/xray/config/04_inbounds.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq
echo ""
echo -e "${YB}Ana menüye dönmek için enter'a basın${NC}"
echo -e "${BB}————————————————————————————————————————————————————${NC}"
read -rp "Silinecek Kullanıcı Adı: " user
if [ -z $user ]; then
    allxray
else
    exp=$(grep -wE "^#&@ $user" "/usr/local/etc/xray/config/04_inbounds.json" | cut -d ' ' -f 3 | sort | uniq)
    sed -i "/^#&@ $user $exp/,/^},{/d" /usr/local/etc/xray/config/04_inbounds.json
    rm -rf /var/www/html/xray/xray-$user.log
    rm -rf /user/xray-$user.log
    systemctl restart xray
    clear
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "          ${WB}Xray Hesabı Başarıyla Silindi${NC}          "
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e " ${YB}Kullanıcı Adı   :${NC} $user"
    echo -e " ${YB}Bitiş Tarihi    :${NC} $exp"
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo ""
    read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın"
    clear
    allxray
fi
