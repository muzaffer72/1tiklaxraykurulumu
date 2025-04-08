#!/bin/bash

# Çıktı için renkler (ihtiyaca göre ayarlayın)
NC='\e[0m'       # Renksiz (metin rengini varsayılana sıfırlar)
DEFBOLD='\e[39;1m' # Varsayılan Kalın
RB='\e[31;1m'    # Kırmızı Kalın
GB='\e[32;1m'    # Yeşil Kalın
YB='\e[33;1m'    # Sarı Kalın
BB='\e[34;1m'    # Mavi Kalın
MB='\e[35;1m'    # Magenta Kalın
CB='\e[36;1m'    # Cyan Kalın
WB='\e[37;1m'    # Beyaz Kalın

# Menüyü gösterme fonksiyonu
show_allxray_menu() {
    clear
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e "             ${WB}----- [ Tüm Xray Menüsü ] -----${NC}            "
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e ""
    echo -e " ${MB}[1]${NC} ${YB}Xray Oluştur${NC}"
    echo -e " ${MB}[2]${NC} ${YB}Xray Süresini Uzat${NC}"
    echo -e " ${MB}[3]${NC} ${YB}Xray Hesabını Sil${NC}"
    echo -e " ${MB}[4]${NC} ${YB}Kullanıcı Giriş Bilgilerini Görüntüle${NC}"
    echo -e ""
    echo -e " ${MB}[0]${NC} ${YB}Ana Menüye Dön${NC}"
    echo -e ""
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e ""
}

# Menü girişlerini işleme fonksiyonu
handle_allxray_menu() {
    read -p " Menü seçiminiz :  "  opt
    echo -e ""
    case $opt in
        1) clear ; create-xray ;;
        2) clear ; extend-xray ;;
        3) clear ; del-xray ;;
        4) clear ; cek-xray ;;
        0) clear ; menu ;;
        *) echo -e "${YB}Geçersiz seçim! Lütfen tekrar deneyin.${NC}" ; sleep 1 ; show_allxray_menu ;;
    esac
}

# Menüyü göster ve kullanıcı girişini işle
while true; do
    show_allxray_menu
    handle_allxray_menu
done
