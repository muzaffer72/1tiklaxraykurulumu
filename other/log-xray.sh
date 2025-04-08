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

# Gecikme ile bilgi gösterme fonksiyonu
info() {
    echo -e "${GB}[ BİLGİ ]${NC} ${YB}$1${NC}"
    sleep 0.5
}

# Gecikme ile uyarı gösterme fonksiyonu
warning() {
    echo -e "${RB}[ UYARI ]${NC} ${YB}$1${NC}"
    sleep 0.5
}

# İstemci olmadığında menü gösterme fonksiyonu
no_clients_menu() {
    clear
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "                ${WB}Tüm Xray Hesap Günlükleri${NC}                "
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "  ${YB}Herhangi bir istemci bulunamadı!${NC}"
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo ""
    read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın"
    menu
}

clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#&@ " "/usr/local/etc/xray/config/04_inbounds.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    no_clients_menu
fi

clear
echo -e "${BB}————————————————————————————————————————————————————${NC}"
echo -e "                ${WB}Tüm Xray Hesap Günlükleri${NC}                "
echo -e "${BB}————————————————————————————————————————————————————${NC}"
echo -e " ${YB}Kullanıcı Adı      Bitiş Tarihi${NC}  "
echo -e "${BB}————————————————————————————————————————————————————${NC}"
grep -E "^#&@ " "/usr/local/etc/xray/config/04_inbounds.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq
echo ""
echo -e "${YB}Ana menüye dönmek için enter'a basın${NC}"
echo -e "${BB}————————————————————————————————————————————————————${NC}"
read -rp "Kullanıcı Adı Girin: " user
if [[ -z $user ]]; then
    menu
else
    clear
    log_file="/user/xray-$user.log"
    if [[ -f $log_file ]]; then
        echo -e "$(cat "$log_file")"
    else
        warning "$user kullanıcısı için günlük dosyası bulunamadı."
    fi
    echo ""
    read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın"
    menu
fi
