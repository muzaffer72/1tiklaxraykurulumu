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
show_menu() {
    clear
    python /usr/bin/system_info.py
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    # Domain bilgisini al
    domain=$(cat /usr/local/etc/xray/dns/domain)
    echo -e "               ${WB}----- [ $domain ] -----${NC}"
    
    # Kullanıcı adını almak için farklı yöntemler
    # 1. Mevcut kullanıcıyı al
    current_user=$(whoami)
    
    # 2. Var olan xray hesaplarını listeleme
    # /var/www/html/xray/ dizinindeki hesap dosyalarını bulma
    user_files=$(find /var/www/html/xray/ -name "xray-*.html" 2>/dev/null | sed 's|.*/xray-\(.*\)\.html|\1|')
    
    # Eğer dosyalar bulunduysa
    if [ -n "$user_files" ]; then
        echo -e "${YB}Mevcut hesaplar:${NC}"
        # Her hesap için bağlantı bilgisi görüntüle
        for user in $user_files; do
            echo -e "Bağlantılar ${GB}https://$domain/xray/xray-$user.html${NC}" | tee -a /root/xray-accounts.log
        done
    else
        # Eğer hesap dosyası bulunamadıysa
        echo -e "${YB}Bağlantılar:${NC} ${RB}Henüz hesap oluşturulmamış.${NC}" 
        echo -e "${GB}Hesap oluşturmak için Xray Menüsü'nü (1) kullanın.${NC}"
    fi
    
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e " ${MB}[1]${NC} ${YB}Xray Menüsü${NC}"
    echo -e " ${MB}[2]${NC} ${YB}Xray Yönlendirme${NC}"
    echo -e " ${MB}[3]${NC} ${YB}Xray İstatistikleri${NC}"
    echo -e " ${MB}[4]${NC} ${YB}Hesap Oluşturma Günlüğü${NC}"
    echo -e " ${MB}[5]${NC} ${YB}Xray-core Güncelle${NC}"
    echo -e " ${MB}[6]${NC} ${YB}Hız Testi${NC}"
    echo -e " ${MB}[7]${NC} ${YB}Alan Adı Değiştir${NC}"
    echo -e " ${MB}[8]${NC} ${YB}Acme.sh Sertifikası${NC}"
    echo -e " ${MB}[9]${NC} ${YB}Betik Hakkında${NC}"
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e ""
    # echo -e "${RB}Alan adını değiştirirseniz, oluşturduğunuz hesaplar kaybolacaktır, bu yüzden lütfen dikkatli olun.${NC}"
}

# Menü girişlerini işleme fonksiyonu
handle_menu() {
    read -p " Menü Seçimi :  " opt
    echo -e ""
    case $opt in
        1) clear ; allxray ;;
        2) clear ; route-xray ;;
        3) clear ; python /usr/bin/traffic.py ; echo " " ; read -n 1 -s -r -p "Menüye dönmek için herhangi bir tuşa basın" ; show_menu ;;
        4) clear ; log-xray ;;
        5) clear ; update-xray ;;
        6) clear ; speedtest ; echo " " ; read -n 1 -s -r -p "Menüye dönmek için herhangi bir tuşa basın" ; show_menu ;;
        7) clear ; dns ;;
        8) clear ; certxray ;;
        9) clear ; about ;;
        *) echo -e "${YB}Geçersiz giriş${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Menüyü göster ve kullanıcı girişini işle
while true; do
    show_menu
    handle_menu
done
