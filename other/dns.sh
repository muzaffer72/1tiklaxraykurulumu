#!/bin/bash

NC='\e[0m'         # Renksiz (metin rengini varsayılana sıfırlar)
DEFBOLD='\e[39;1m' # Varsayılan Kalın
RB='\e[31;1m'      # Kırmızı Kalın
GB='\e[32;1m'      # Yeşil Kalın
YB='\e[33;1m'      # Sarı Kalın
BB='\e[34;1m'      # Mavi Kalın
MB='\e[35;1m'      # Magenta Kalın
CB='\e[36;1m'      # Cyan Kalın
WB='\e[37;1m'      # Beyaz Kalın

# Renkli mesaj yazdırma fonksiyonu
print_msg() {
    COLOR=$1
    MSG=$2
    echo -e "${COLOR}${MSG}${NC}"
}

# Komut başarısını kontrol etme fonksiyonu
check_success() {
    if [ $? -eq 0 ]; then
        print_msg $GB "Başarılı"
    else
        print_msg $RB "Başarısız: $1"
        exit 1
    fi
}

# Hata mesajı gösterme fonksiyonu
print_error() {
    MSG=$1
    print_msg $RB "Hata: ${MSG}"
}

# Cloudflare API kimlik bilgilerinizi ayarlayın
API_EMAIL="guzelim.batmanli@gmail.com"
API_KEY="4aa140cf85fde3adadad1856bdf67cf5ad460"  # Buraya Cloudflare Global API Key'inizi girin

# DNS kayıt detaylarını ayarlayın
TYPE_A="A"
TYPE_CNAME="CNAME"
IP_ADDRESS=$(curl -sS ipv4.icanhazip.com)

# Alan adı doğrulama fonksiyonu
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Alan adı giriş fonksiyonu
input_domain() {
    while true; do
        clear
        echo -e "${BB}————————————————————————————————————————————————————————"
        echo -e "${YB}                 ÖZEL ALAN ADI AYARLARI"
        echo -e "${BB}————————————————————————————————————————————————————————"
        echo -e "${YB}Seçenek Belirleyin:"
        echo -e "${WB}1. Kendi alan adımı gir"
        echo -e "${WB}2. onvao.net alt alan adı oluştur"
        echo -e "${GB}3. Geri${NC}"
        
        read -rp $'\e[33;1mSeçiminizi girin: \e[0m' domain_choice
        
        case $domain_choice in
            1)
                echo -e "${YB}Alan Adı Girin${NC}"
                echo " "
                read -rp $'\e[33;1mAlan adınızı girin: \e[0m' -e dns

                if [ -z "$dns" ]; then
                    echo -e "${RB}Alan adı girilmedi!${NC}"
                    sleep 2
                    continue
                elif ! validate_domain "$dns"; then
                    echo -e "${RB}Alan adı formatı geçersiz! Lütfen geçerli bir alan adı girin.${NC}"
                    sleep 2
                    continue
                else
                    echo "$dns" > /usr/local/etc/xray/dns/domain
                    echo "DNS=$dns" > /var/lib/dnsvps.conf
                    echo -e "Alan adı ${GB}${dns}${NC} başarıyla kaydedildi"
                    update_nginx_config
                    sleep 2
                    break
                fi
                ;;
            2)
                DOMAIN="onvao.net"
                
                while true; do
                    echo -e "${YB}onvao.net için alt alan adı seçeneği:"
                    echo -e "${WB}1. Rastgele alt alan adı oluştur"
                    echo -e "${WB}2. Özel alt alan adı oluştur${NC}"
                    echo -e " "
                    echo -e "${GB}3. Geri${NC}"
                    
                    read -rp $'\e[33;1mSeçiminizi girin: \e[0m' sub_domain_choice
                    
                    case $sub_domain_choice in
                        1)
                            NAME_A="$(openssl rand -hex 2).$DOMAIN"
                            NAME_CNAME="*.$NAME_A"
                            TARGET_CNAME="$NAME_A"
                            
                            get_zone_id
                            delete_records_based_on_ip
                            create_A_record
                            create_CNAME_record
                            update_nginx_config
                            return
                            ;;
                        2)
                            while true; do
                                read -rp $'\e[33;1mAlt alan adını girin (sadece küçük harfler ve rakamlar, boşluk olmadan): \e[0m' custom_dns_name
                                
                                if [[ ! "$custom_dns_name" =~ ^[a-z0-9-]+$ ]]; then
                                    echo -e "${RB}Alt alan adı sadece küçük harfler, rakamlar ve tire içerebilir, boşluk olmadan!${NC}"
                                    sleep 2
                                    continue
                                fi
                                
                                if [ -z "$custom_dns_name" ]; then
                                    echo -e "${RB}Alt alan adı boş olamaz!${NC}"
                                    sleep 2
                                    continue
                                fi
                                
                                NAME_A="$custom_dns_name.$DOMAIN"
                                NAME_CNAME="*.$NAME_A"
                                TARGET_CNAME="$NAME_A"

                                get_zone_id
                                if check_dns_record "$NAME_A" "$ZONE_ID"; then
                                    echo -e "${RB}Bu alt alan adı zaten mevcut! Lütfen farklı bir ad deneyin.${NC}"
                                    sleep 2
                                else
                                    delete_records_based_on_ip
                                    create_A_record
                                    create_CNAME_record
                                    update_nginx_config
                                    return
                                fi
                            done
                            ;;
                        3)
                            break
                            ;;
                        *)
                            echo -e "${RB}Geçersiz seçim!${NC}"
                            sleep 2
                            ;;
                    esac
                done
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RB}Geçersiz seçim!${NC}"
                sleep 2
                ;;
        esac
    done
}

# Alan ID'sini alma fonksiyonu
get_zone_id() {
  echo -e "${YB}Alan ID'si alınıyor...${NC}"
  ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ "$ZONE_ID" == "null" ]; then
    echo -e "${RB}Alan ID'si alınamadı${NC}"
    exit 1
  fi

  # Alan ID'sini sensörleme (ilk ve son 3 karakteri gösterme)
  ZONE_ID_SENSORED="${GB}${ZONE_ID:0:3}*****${ZONE_ID: -3}"

  echo -e "${YB}Alan ID'si: $ZONE_ID_SENSORED${NC}"
}

# API yanıtını işleme fonksiyonu
handle_response() {
  local response=$1
  local action=$2

  success=$(echo $response | jq -r '.success')
  if [ "$success" == "true" ]; then
    echo -e "$action ${YB}başarılı.${NC}"
  else
    echo -e "$action ${RB}başarısız.${NC}"
    errors=$(echo $response | jq -r '.errors[] | .message')
    echo -e "${RB}Hata: $errors${NC}"
  fi
}

# Mevcut DNS kaydını silme fonksiyonu
delete_record() {
  local record_name=$1
  local record_type=$2
  local zone_id=${3:-$ZONE_ID}

  RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$record_name" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ "$RECORD_ID" != "null" ]; then
    echo -e "${YB}Mevcut $record_type kaydı siliniyor: ${CB}$record_name${NC} ${YB}.....${NC}"
    response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$RECORD_ID" \
      -H "X-Auth-Email: $API_EMAIL" \
      -H "X-Auth-Key: $API_KEY" \
      -H "Content-Type: application/json")
    handle_response "$response" "${YB}$record_type kaydı silindi:${NC} ${CB}$record_name${NC}"
  fi
}

# IP adresine göre DNS kayıtlarını silme fonksiyonu
delete_records_based_on_ip() {
  echo -e "${YB}IP adresine göre DNS kayıtları siliniyor: ${CB}$IP_ADDRESS${NC} ${YB}.....${NC}"

  # Bölgedeki tüm DNS kayıtlarını alma
  dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json")

  # Eşleşen A kayıtlarını ve ilgili CNAME kayıtlarını çözümleme ve silme
  echo "$dns_records" | jq -c '.result[] | select(.type == "A" and .content == "'"$IP_ADDRESS"'")' | while read -r record; do
    record_name=$(echo "$record" | jq -r '.name')
    delete_record "$record_name" "A"
    # İlgili CNAME kayıtlarını silme
    cname_record=$(echo "$dns_records" | jq -c '.result[] | select(.type == "CNAME" and .content == "'"$record_name"'")')
    if [ -n "$cname_record" ]; then
      cname_record_name=$(echo "$cname_record" | jq -r '.name')
      delete_record "$cname_record_name" "CNAME"
    fi
  done
}

# A kaydı oluşturma fonksiyonu
create_A_record() {
  echo -e "${YB}A kaydı ekleniyor: $GB$NAME_A$NC $YB.....${NC}"
  response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    --data '{
      "type": "'$TYPE_A'",
      "name": "'$NAME_A'",
      "content": "'$IP_ADDRESS'",
      "ttl": 0,
      "proxied": false
    }')
  echo "$NAME_A" > /usr/local/etc/xray/dns/domain
  echo "DNS=$NAME_A" > /var/lib/dnsvps.conf
  handle_response "$response" "${YB}A kaydı eklendi: $GB$NAME_A$NC"
}

# CNAME kaydı oluşturma fonksiyonu
create_CNAME_record() {
  echo -e "${YB}Wildcard için CNAME kaydı ekleniyor: $GB$NAME_CNAME$NC $YB.....${NC}"
  response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    --data '{
      "type": "'$TYPE_CNAME'",
      "name": "'$NAME_CNAME'",
      "content": "'$TARGET_CNAME'",
      "ttl": 0,
      "proxied": false
    }')
  handle_response "$response" "${YB}Wildcard için CNAME kaydı eklendi: $GB$NAME_CNAME$NC"
}

# DNS kaydının zaten var olup olmadığını kontrol etme fonksiyonu
check_dns_record() {
  local record_name=$1
  local zone_id=$2

  RECORD_EXISTS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result | length')

  if [ "$RECORD_EXISTS" -gt 0 ]; then
    return 0  # Kayıt var
  else
    return 1  # Kayıt yok
  fi
}

# Nginx yapılandırmasını güncelleme
update_nginx_config() {
    # Dosyadan yeni domain adını alma
    NEW_DOMAIN=$(cat /usr/local/etc/xray/dns/domain)
    # Nginx yapılandırmasında server_name'i güncelleme
    wget -q -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/muzaffer72/1tiklaxraykurulumu/main/nginx.conf
    sed -i "s/server_name web.com;/server_name $NEW_DOMAIN;/g" /etc/nginx/nginx.conf
    sed -i "s/server_name \*.web.com;/server_name \*.$NEW_DOMAIN;/" /etc/nginx/nginx.conf

    # Değişikliklerden sonra Nginx yapılandırmasının geçerli olup olmadığını kontrol etme
    if nginx -t &> /dev/null; then
        # Eğer yapılandırma geçerliyse, Nginx'i yeniden yükleme
        systemctl reload nginx
        print_msg $GB "Nginx yapılandırması başarıyla yeniden yüklendi."
    else
        # Eğer Nginx yapılandırması geçerli değilse, hata mesajı gösterme
        print_msg $RB "Nginx yapılandırma testi başarısız oldu. Lütfen yapılandırmanızı kontrol edin."
    fi
}

# Ana menüyü görüntüleme fonksiyonu
setup_domain() {
    while true; do
        clear

        # Başlığı görüntüleme
        echo -e "${BB}————————————————————————————————————————————————————————"
        echo -e "${YB}                     ALAN ADI AYARLARI"
        echo -e "${BB}————————————————————————————————————————————————————————"

        # Alan adı seçeneklerini görüntüleme
        echo -e "${YB}Seçenek Belirleyin:"
        echo -e "${WB}1. Hazır alan adlarını kullan"
        echo -e "${WB}2. Kendi alan adımı kullan"

        # Kullanıcıdan seçim isteme
        read -rp $'\e[33;1mSeçiminizi girin: \e[0m' choice

        # Kullanıcı seçimini işleme
        case $choice in
            1)
                while true; do
                    echo -e "${YB}Alan Adınızı Seçin:"
                    echo -e "${WB}1. vless.sbs"
                    echo -e "${WB}2. airi.buzz"
                    echo -e "${WB}3. drm.icu${NC}"
                    echo -e " "
                    echo -e "${GB}4. Geri${NC}"
                    read -rp $'\e[33;1mSeçiminizi girin: \e[0m' domain_choice
                    case $domain_choice in
                        1)
                            DOMAIN="vless.sbs"
                            
                            ;;
                        2)
                            DOMAIN="airi.buzz"
                            
                            ;;
                        3)
                            DOMAIN="drm.icu"
                            
                            ;;
                        4)
                            break
                            ;;
                        *)
                            echo -e "${RB}Geçersiz seçim!${NC}"
                            sleep 2
                            continue
                            ;;
                    esac

                    while true; do
                        echo -e "${YB}DNS adı için seçenek belirleyin:"
                        echo -e "${WB}1. Rastgele DNS adı oluştur"
                        echo -e "${WB}2. Özel DNS adı oluştur${NC}"
                        echo -e " "
                        echo -e "${GB}3. Geri${NC}"
                        read -rp $'\e[33;1mSeçiminizi girin: \e[0m' dns_name_choice
                        case $dns_name_choice in
                            1)
                                NAME_A="$(openssl rand -hex 2).$DOMAIN"
                                NAME_CNAME="*.$NAME_A"
                                TARGET_CNAME="$NAME_A"
                                get_zone_id
                                delete_records_based_on_ip
                                create_A_record
                                create_CNAME_record
                                update_nginx_config
                                return
                                ;;
                            2)
                                while true; do
                                    read -rp $'\e[33;1mDNS adınızı girin (sadece küçük harfler ve rakamlar, boşluk olmadan): \e[0m' custom_dns_name
                                    if [[ ! "$custom_dns_name" =~ ^[a-z0-9-]+$ ]]; then
                                        echo -e "${RB}DNS adı sadece küçük harfler, rakamlar ve tire içerebilir, boşluk olmadan!${NC}"
                                        sleep 2
                                        continue
                                    fi
                                    if [ -z "$custom_dns_name" ]; then
                                        echo -e "${RB}DNS adı boş olamaz!${NC}"
                                        sleep 2
                                        continue
                                    fi
                                    NAME_A="$custom_dns_name.$DOMAIN"
                                    NAME_CNAME="*.$NAME_A"
                                    TARGET_CNAME="$NAME_A"

                                    get_zone_id
                                    if check_dns_record "$NAME_A" "$ZONE_ID"; then
                                        echo -e "${RB}DNS adı zaten mevcut! Lütfen farklı bir ad deneyin.${NC}"
                                        sleep 2
                                    else
                                        # get_zone_id
                                        delete_records_based_on_ip
                                        create_A_record
                                        create_CNAME_record
                                        update_nginx_config
                                        return
                                    fi
                                done
                                ;;
                            3)
                                break
                                ;;
                            *)
                                echo -e "${RB}Geçersiz seçim!${NC}"
                                sleep 2
                                ;;
                        esac
                    done
                done
                ;;
            2)
                input_domain
                break
                ;;
            *)
                echo -e "${RB}Geçersiz seçim!${NC}"
                sleep 2
                ;;
        esac
    done

    sleep 2
}

# Ana menüyü çalıştırma
setup_domain

input_menu() {
    # Menüye dönüş işlemleri
    echo -e "${RB}Sertifikanızı yenilemeyi unutmayın.${NC}"
    sleep 5
    echo -e "${YB}Menüye dönülüyor...${NC}"
    sleep 2
    clear
    menu
}

# Menüye dönüş fonksiyonunu çağırma
input_menu
