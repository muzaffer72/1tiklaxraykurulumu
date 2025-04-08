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
API_KEY="4aa140cf85fde3adadad1856bdf67cf5ad460"

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
        echo -e "${YB}Alan Adı Girin${NC}"
        echo " "
        read -rp $'\e[33;1mAlan adınızı girin: \e[0m' -e dns

        if [ -z "$dns" ]; then
            echo -e "${RB}Alan adı girilmedi!${NC}"
        elif ! validate_domain "$dns"; then
            echo -e "${RB}Alan adı formatı geçersiz! Lütfen geçerli bir alan adı girin.${NC}"
        else
            echo "$dns" > /usr/local/etc/xray/dns/domain
            echo "DNS=$dns" > /var/lib/dnsvps.conf
            echo -e "Alan adı ${GB}${dns}${NC} başarıyla kaydedildi"
            break
        fi
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

# Update Nginx configuration
update_nginx_config() {
    # Get new domain from file
    NEW_DOMAIN=$(cat /usr/local/etc/xray/dns/domain)
    # Update server_name in Nginx configuration
    wget -q -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/muzaffer72/1tiklaxraykurulumu/main/nginx.conf
    sed -i "s/server_name web.com;/server_name $NEW_DOMAIN;/g" /etc/nginx/nginx.conf
    sed -i "s/server_name \*.web.com;/server_name \*.$NEW_DOMAIN;/" /etc/nginx/nginx.conf

    # Check if Nginx configuration is valid after changes
    if nginx -t &> /dev/null; then
        # Reload Nginx configuration if valid
        systemctl reload nginx
        print_msg $GB "Nginx configuration reloaded successfully."
    else
        # If Nginx configuration is not valid, display error message
        print_msg $RB "Nginx configuration test failed. Please check your configuration."
    fi
}

# Fungsi untuk menampilkan menu utama
setup_domain() {
    while true; do
        clear

        # Menampilkan judul
        echo -e "${BB}————————————————————————————————————————————————————————"
        echo -e "${YB}                      SETUP DOMAIN"
        echo -e "${BB}————————————————————————————————————————————————————————"

        # Menampilkan pilihan untuk menggunakan domain acak atau domain sendiri
        echo -e "${YB}Pilih Opsi:"
        echo -e "${WB}1. Gunakan domain yang tersedia"
        echo -e "${WB}2. Gunakan domain sendiri"

        # Meminta input dari pengguna untuk memilih opsi
        read -rp $'\e[33;1mMasukkan pilihan Anda: \e[0m' choice

        # Memproses pilihan pengguna
        case $choice in
            1)
                while true; do
                    echo -e "${YB}Pilih Domain anda:"
                    echo -e "${WB}1. vless.sbs"
                    echo -e "${WB}2. airi.buzz"
                    echo -e "${WB}3. drm.icu${NC}"
                    echo -e " "
                    echo -e "${GB}4. kembali${NC}"
                    read -rp $'\e[33;1mMasukkan pilihan Anda: \e[0m' domain_choice
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
                            echo -e "${RB}Pilihan tidak valid!${NC}"
                            sleep 2
                            continue
                            ;;
                    esac

                    while true; do
                        echo -e "${YB}Pilih opsi untuk nama DNS:"
                        echo -e "${WB}1. Buat nama DNS secara acak"
                        echo -e "${WB}2. Buat nama DNS sendiri${NC}"
                        echo -e " "
                        echo -e "${GB}3. Kembali${NC}"
                        read -rp $'\e[33;1mMasukkan pilihan Anda: \e[0m' dns_name_choice
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
                                    read -rp $'\e[33;1mMasukkan nama DNS Anda (hanya huruf kecil dan angka, tanpa spasi): \e[0m' custom_dns_name
                                    if [[ ! "$custom_dns_name" =~ ^[a-z0-9-]+$ ]]; then
                                        echo -e "${RB}Nama DNS hanya boleh mengandung huruf kecil dan angka, tanpa spasi!${NC}"
                                        sleep 2
                                        continue
                                    fi
                                    if [ -z "$custom_dns_name" ]; then
                                        echo -e "${RB}Nama DNS tidak boleh kosong!${NC}"
                                        sleep 2
                                        continue
                                    fi
                                    NAME_A="$custom_dns_name.$DOMAIN"
                                    NAME_CNAME="*.$NAME_A"
                                    TARGET_CNAME="$NAME_A"

                                    get_zone_id
                                    if check_dns_record "$NAME_A" "$ZONE_ID"; then
                                        echo -e "${RB}Nama DNS sudah ada! Silakan coba lagi.${NC}"
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
                                echo -e "${RB}Pilihan tidak valid!${NC}"
                                sleep 2
                                ;;
                        esac
                    done
                done
                ;;
            2)
                input_domain
                update_nginx_config
                break
                ;;
            *)
                echo -e "${RB}Pilihan tidak valid!${NC}"
                sleep 2
                ;;
        esac
    done

    sleep 2
}

# Menjalankan menu utama
setup_domain

input_menu() {
    # Isi dengan fungsi atau perintah untuk menampilkan menu Anda
    echo -e "${RB}Dont forget to renew certificate.${NC}"
    sleep 5
    echo -e "${YB}Returning to menu...${NC}"
    sleep 2
    clear
    menu
    # Contoh: panggil skrip menu atau perintah lain
    # ./menu.sh
}

# Panggil fungsi menu untuk kembali ke menu
input_menu
