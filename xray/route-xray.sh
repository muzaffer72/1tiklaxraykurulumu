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

CONFIG_FILE="/usr/local/etc/xray/config/06_routing.json"

# Doğrulama Fonksiyonu
verification_1st() {
    # Değişiklikleri doğrula
    if grep -q '"outboundTag": "warp"' $CONFIG_FILE; then
        echo -e "${GB}Değişiklikler başarıyla yapıldı.${NC}"
    else
        echo -e "${RB}Değişiklikler başarısız, lütfen yapılandırma dosyasını kontrol edin.${NC}"
    fi
}

# Doğrulama Fonksiyonu
verification_2nd() {
    # Değişiklikleri doğrula
    if grep -q '"outboundTag": "direct"' $CONFIG_FILE; then
        echo -e "${GB}Değişiklikler başarıyla yapıldı.${NC}"
    else
        echo -e "${RB}Değişiklikler başarısız, lütfen yapılandırma dosyasını kontrol edin.${NC}"
    fi
}

# Tüm trafiği WARP üzerinden yönlendirme fonksiyonu
route_all_traffic() {
    # 'direct' ifadesini 'warp' ile değiştirmek için 'sed' kullanma
    # sed -i '/"inboundTag": \[/,/"type": "field"/ s/"outboundTag": "direct"/"outboundTag": "warp"/' $CONFIG_FILE
    sed -i 's/"outboundTag": "direct"/"outboundTag": "warp"/g' $CONFIG_FILE
    verification_1st
    systemctl restart xray
}

# Bazı web sitesi trafiğini WARP üzerinden yönlendirme fonksiyonu
route_some_traffic() {
    # Belirli alanlar için 'direct' ifadesini 'warp' ile değiştirmek için 'sed' kullanma
    sed -i '/"domain": \[/,/"type": "field"/ s/"outboundTag": "direct"/"outboundTag": "warp"/' $CONFIG_FILE
    verification_1st
    systemctl restart xray
}

# WARP yönlendirmesini devre dışı bırakma fonksiyonu
disable_route() {
    # 'warp' ifadesini 'direct' ile değiştirmek için 'sed' kullanma
    sed -i 's/"outboundTag": "warp"/"outboundTag": "direct"/g' $CONFIG_FILE
    systemctl restart xray
}

function_1st() {
  disable_route
  route_all_traffic
}
function_2nd() {
  disable_route
  route_some_traffic
}
function_3rd() {
  disable_route
  verification_2nd
}

# Menü gösterme fonksiyonu
show_wg_menu() {
    clear
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e "             ${WB}----- [ Xray Yönlendirme Menüsü ] -----${NC}            "
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e ""
    echo -e " ${MB}[1]${NC} ${YB}Tüm trafiği WARP üzerinden yönlendir${NC}"
    echo -e " ${MB}[2]${NC} ${YB}Bazı web sitesi trafiğini WARP üzerinden yönlendir${NC}"
    echo -e " ${MB}[3]${NC} ${YB}WARP yönlendirmesini devre dışı bırak${NC}"
    echo -e ""
    echo -e " ${MB}[0]${NC} ${YB}Menüye Dön${NC}"
    echo -e ""
    echo -e "${BB}————————————————————————————————————————————————————————${NC}"
    echo -e ""
}

# Menü girişlerini işleme fonksiyonu
handle_wg_menu() {
    read -p " Menü seçimi :  "  opt
    echo -e ""
    case $opt in
        1) function_1st ; sleep 2 ;;
        2) function_2nd ; sleep 2 ;;
        3) function_3rd ; sleep 2 ;;
        0) clear ; menu ;;
        *) echo -e "${YB}Geçersiz giriş${NC}" ; sleep 1 ; show_wg_menu ;;
    esac
}

# Menüyü göster ve kullanıcı girişini işle
while true; do
    show_wg_menu
    handle_wg_menu
done