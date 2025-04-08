#!/bin/bash

# Metin renkleri ve stilleri
NC='\e[0m'        # Renksiz
DEFBOLD='\e[39;1m' # Varsayılan metin rengi kalın
RB='\e[31;1m'      # Kırmızı kalın
GB='\e[32;1m'      # Yeşil kalın
YB='\e[33;1m'      # Sarı kalın
BB='\e[34;1m'      # Mavi kalın
MB='\e[35;1m'      # Magenta kalın
CB='\e[36;1m'      # Cyan kalın
WB='\e[37;1m'      # Beyaz kalın

# Başlık gösterme fonksiyonu
function display_header() {
    clear
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
    echo -e "             ${WB}Tüm Xray Kullanıcı Giriş Hesapları${NC}           "
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
}

# Menü gösterme fonksiyonu
function display_menu() {
    echo -e "${YB}1. Hesap verilerini yenile${NC}"
    echo -e "${YB}2. Çıkış${NC}"
    echo -e "${BB}————————————————————————————————————————————————————${NC}"
}

# Kullanıcıları ve giriş yapan IP'leri görüntüleme fonksiyonu
function display_users() {
    local config_file="/usr/local/etc/xray/config/04_inbounds.json"
    local log_file="/var/log/xray/access.log"

    if [[ ! -f "$config_file" ]]; then
        echo -e "${RB}Yapılandırma dosyası bulunamadı: $config_file${NC}"
        return
    fi

    if [[ ! -f "$log_file" ]]; then
        echo -e "${RB}Günlük dosyası bulunamadı: $log_file${NC}"
        return
    fi

    local data=($(grep '^#&@' "$config_file" | cut -d ' ' -f 2 | sort | uniq))
    if [ ${#data[@]} -eq 0 ]; then
        echo -e "${RB}Kullanıcı hesabı bulunamadı.${NC}"
        return
    fi

    for akun in "${data[@]}"; do
        [ -z "$akun" ] && akun="Yok"

        local data2=($(tail -n 500 "$log_file" | awk '{print $3}' | sed 's/tcp://g' | cut -d ":" -f 1 | sort | uniq))

        if [ ${#data2[@]} -eq 0 ]; then
            echo -e "${YB}$YB$akun$NC kullanıcısı için IP adresi bulunamadı.${NC}"
            continue
        fi

        echo -n > /tmp/ipxray
        echo -n > /tmp/other

        for ip in "${data2[@]}"; do
            local jum=$(grep -w "$akun" "$log_file" | tail -n 500 | awk '{print $3}' | sed 's/tcp://g' | cut -d ":" -f 1 | grep -w "$ip" | sort | uniq)
            if [[ "$jum" == "$ip" ]]; then
                echo "$jum" >> /tmp/ipxray
            else
                echo "$ip" >> /tmp/other
            fi
        done

        local jum=$(cat /tmp/ipxray)
        if [ -n "$jum" ]; then
            local jum2=$(nl < /tmp/ipxray)
            echo -e "${MB}Kullanıcı: ${WB}$akun${NC}"
            echo -e "${GB}$jum2${NC}"
            echo -e "${BB}————————————————————————————————————————————————————${NC}"
        fi

        rm -f /tmp/ipxray /tmp/other
    done
}

# Ana fonksiyon
function main() {
    while true; do
        display_header
        display_users
        display_menu
        read -p "Seçenek seçin [1-2]: " choice

        case $choice in
            1) ;;
            2) echo -e "${YB}Çıkılıyor...${NC}"; sleep 2 ; clear ; menu ;;
            *) echo -e "${RB}Geçersiz seçenek!${NC}"; sleep 1 ;;
        esac
    done
}

# Ana fonksiyonu çalıştır
main