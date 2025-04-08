#!/bin/bash

rm -rf install.sh
clear
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

secs_to_human() {
echo -e "${WB}Kurulum süresi : $(( ${1} / 3600 )) saat $(( (${1} / 60) % 60 )) dakika $(( ${1} % 60 )) saniye${NC}"
}
start=$(date +%s)

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

# Kullanıcının root olduğundan emin olma
if [ "$EUID" -ne 0 ]; then
  print_error "Lütfen bu betiği root olarak çalıştırın."
  exit 1
fi

# Karşılama
print_msg $YB "Hoş geldiniz! Bu betik sisteminize bazı önemli paketleri yükleyecek."

# Paket listesini güncelleme
print_msg $YB "Paket listesi güncelleniyor..."
apt update -y
check_success
sleep 1

# İlk paketlerin kurulumu
print_msg $YB "socat, netfilter-persistent ve bsdmainutils yükleniyor..."
apt install socat netfilter-persistent bsdmainutils -y
check_success
sleep 1

# İkinci paketlerin kurulumu
print_msg $YB "vnstat, lsof ve fail2ban yükleniyor..."
apt install vnstat lsof fail2ban -y
check_success
sleep 1

# Üçüncü paketlerin kurulumu
print_msg $YB "jq, curl, sudo ve cron yükleniyor..."
apt install jq curl sudo cron -y
check_success
sleep 1

# Dördüncü paketlerin kurulumu
print_msg $YB "build-essential ve diğer bağımlılıklar yükleniyor..."
apt install build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev gcc clang llvm g++ valgrind make cmake debian-keyring debian-archive-keyring apt-transport-https systemd bind9-host gnupg2 ca-certificates lsb-release ubuntu-keyring debian-archive-keyring -y
apt install unzip python-is-python3 python3-pip -y
pip install psutil pandas tabulate rich py-cpuinfo distro requests pycountry geoip2 --break-system-packages
check_success
sleep 1

# Tamamlandı mesajı
print_msg $GB "Tüm paketler başarıyla yüklendi!"
sleep 3

# Zaman dilimini İstanbul olarak ayarla
print_msg $YB "Zaman dilimi İstanbul olarak ayarlanıyor..."
timedatectl set-timezone Europe/Istanbul
check_success "Zaman dilimi ayarlanamadı."
print_msg $GB "Zaman dilimi İstanbul olarak ayarlandı."
sleep 1

clear

# Karşılama
print_msg $YB "Hoş geldiniz! Bu betik Xray-core'u yükleyecek ve sisteminizde bazı yapılandırmalar yapacak."

# Gerekli dizinleri oluşturma
print_msg $YB "Gerekli dizinler oluşturuluyor..."
sudo mkdir -p /user /tmp /usr/local/etc/xray /var/log/xray
check_success "Dizinler oluşturulamadı."

# Varsa eski yapılandırma dosyalarını silme
print_msg $YB "Eski yapılandırma dosyaları siliniyor..."
sudo rm -f /usr/local/etc/xray/city /usr/local/etc/xray/org /usr/local/etc/xray/timezone /usr/local/etc/xray/region
check_success "Eski yapılandırma dosyaları silinemedi."

# İşletim sistemi ve dağıtımı algılama fonksiyonu
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        print_msg $RB "İşletim sistemi algılanamıyor. Bu betik yalnızca Debian ve Red Hat tabanlı dağıtımları destekler."
        exit 1
    fi
}

# Xray-core'un en son sürümünü kontrol etme fonksiyonu
get_latest_xray_version() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ]; then
        print_msg $RB "Xray-core'un en son sürümü bulunamadı."
        exit 1
    fi
}

# Xray-core'u yükleme fonksiyonu
install_xray_core() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="64"
            ;;
        aarch64)
            ARCH="arm64-v8a"
            ;;
        *)
            print_msg $RB "$ARCH mimarisi desteklenmiyor."
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/$LATEST_VERSION/Xray-linux-$ARCH.zip"

    # Xray-core'u indirme ve çıkarma
    print_msg $YB "Xray-core indiriliyor ve yükleniyor..."
    curl -L -o xray.zip $DOWNLOAD_URL
    check_success "Xray-core indirilemedi."

    sudo unzip -o xray.zip -d /usr/local/bin
    check_success "Xray-core çıkarılamadı."
    rm xray.zip

    sudo chmod +x /usr/local/bin/xray
    check_success "Xray-core için çalıştırma izni ayarlanamadı."

    # systemd servisi oluşturma
    print_msg $YB "Xray-core için systemd servisi yapılandırılıyor..."
    sudo bash -c 'cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=nobody
Group=nogroup
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -confdir /usr/local/etc/xray/config/
RestartSec=5
Restart=always
StandardOutput=file:/var/log/xray/access.log
StandardError=file:/var/log/xray/error.log
SyslogIdentifier=xray
LimitNOFILE=infinity
OOMScoreAdjust=100

[Install]
WantedBy=multi-user.target
EOF'
    check_success "Xray-core için systemd servisi yapılandırılamadı."

    sudo systemctl daemon-reload
    sudo systemctl enable xray
    sudo systemctl start xray
    check_success "Xray-core servisi başlatılamadı."
}

# İşletim sistemi algılama
print_msg $YB "İşletim sistemi algılanıyor..."
detect_os

# İşletim sisteminin desteklenip desteklenmediğini kontrol etme
if [[ "$OS" == "Ubuntu" || "$OS" == "Debian" || "$OS" == "Debian GNU/Linux" || "$OS" == "CentOS" || "$OS" == "Fedora" || "$OS" == "Red Hat Enterprise Linux" ]]; then
    print_msg $GB "İşletim sistemi algılandı: $OS $VERSION"
else
    print_msg $RB "Bu betik $OS dağıtımını desteklemiyor. Kurulum iptal edildi."
    exit 1
fi

# Xray-core'un en son sürümünü kontrol etme
print_msg $YB "Xray-core'un en son sürümü kontrol ediliyor..."
get_latest_xray_version
print_msg $GB "Xray-core'un en son sürümü: $LATEST_VERSION"

# Bağımlılıkları kurma
print_msg $YB "Bağımlılıklar kuruluyor..."
if [[ "$OS" == "Ubuntu" || "$OS" == "Debian" ]]; then
    sudo apt update
    sudo apt install -y curl unzip
elif [[ "$OS" == "CentOS" || "$OS" == "Fedora" || "$OS" == "Red Hat Enterprise Linux" ]]; then
    sudo yum install -y curl unzip
fi
check_success "Bağımlılıklar kurulamadı."

# Xray-core'u kurma
install_xray_core

print_msg $GB "Xray-core $LATEST_VERSION kurulumu tamamlandı."

# ipinfo.io'dan konum bilgileri toplama
print_msg $YB "ipinfo.io'dan konum bilgileri toplanıyor..."
curl -s ipinfo.io/city?token=f209571547ff6b | sudo tee /usr/local/etc/xray/city
curl -s ipinfo.io/org?token=f209571547ff6b | cut -d " " -f 2-10 | sudo tee /usr/local/etc/xray/org
curl -s ipinfo.io/timezone?token=f209571547ff6b | sudo tee /usr/local/etc/xray/timezone
curl -s ipinfo.io/region?token=f209571547ff6b | sudo tee /usr/local/etc/xray/region
check_success "Konum bilgileri toplanamadı."

print_msg $GB "Tüm görevler tamamlandı. Xray-core kuruldu ve konum bilgileriyle yapılandırıldı."
sleep 3
clear

# Kullanıcı interaktif mesajı
print_msg $YB "Hoş geldiniz! Bu betik Speedtest CLI'yi kuracak ve zamanınızı ayarlar."
sleep 3

# Speedtest CLI'yi indirme ve kurma
print_msg $YB "Speedtest CLI indiriliyor ve kuruluyor..."
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash &>/dev/null
sudo apt-get install -y speedtest &>/dev/null
print_msg $YB "Speedtest CLI başarıyla kuruldu."

# Zamanı Asya/Jakarta'ya ayarlama
print_msg $YB "Zamanı Asya/Jakarta'ya ayarlıyor..."
sudo timedatectl set-timezone Asia/Jakarta &>/dev/null
print_msg $YB "Zaman ayarlandı."

# Tamamlama mesajı
print_msg $YB "Kurulum tamamlandı."
sleep 3
clear

# Karşılama
print_msg $YB "Hoş geldiniz! Bu betik ve WireProxy'i WARP'a sisteminde yapılandıracak."

print_msg $YB "WireProxy kurulumu"
rm -rf /usr/local/bin/wireproxy >> /dev/null 2>&1
wget -q -O /usr/local/bin/wireproxy https://github.com/muzaffer72/1tiklaxraykurulumu/raw/main/wireproxy
chmod +x /usr/local/bin/wireproxy
check_success "WireProxy kurulumu başarısız."
print_msg $YB "WireProxy'i yapılandırma"
cat > /etc/wireproxy.conf << END
[Interface]
PrivateKey = 4Osd07VYMrPGDtrJfRaRZ+ynuscBVi4PjzOZmLUJDlE=
Address = 172.16.0.2/32, 2606:4700:110:8fdc:f256:b15d:9e5c:5d1/128
DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001
MTU = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
AllowedIPs = ::/0
Endpoint = engage.cloudflareclient.com:2408

[Socks5]
BindAddress = 127.0.0.1:40000
END
check_success "WireProxy'i yapılandırma başarısız."

print_msg $YB "WireProxy için servis oluşturma"
cat > /etc/systemd/system/wireproxy.service << END
[Unit]
Description=WireProxy for WARP
After=network.target

[Service]
ExecStart=/usr/local/bin/wireproxy -c /etc/wireproxy.conf
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target
END
check_success "WireProxy için servis oluşturulamadı."
sudo systemctl enable wireproxy
sudo systemctl start wireproxy
sudo systemctl daemon-reload
sudo systemctl restart wireproxy
print_msg $YB "Kurulum tamamlandı."
sleep 3
clear

# Karşılama
print_msg $YB "Hoş geldiniz! Bu betik ve Nginx'i sisteminde yapılandıracak."

# Dağıtım ve codename bilgilerini alma
print_msg $YB "Dağıtım ve codename Linux'u algılanıyor..."

# İşletim sistemi algılama fonksiyonu
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
  else
    print_error "OS desteklenmiyor. Sadece Ubuntu ve Debian destekleniyor."
    exit 1
  fi
}

# Nginx deposunu ekleme fonksiyonu
add_nginx_repo() {
  if [ "$OS" == "ubuntu" ]; then
    sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring -y
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  elif [ "$OS" == "debian" ]; then
    sudo apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring -y
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  else
    print_error "OS desteklenmiyor. Sadece Ubuntu ve Debian destekleniyor."
    exit 1
  fi
}

# Nginx'i kurma fonksiyonu
install_nginx() {
  sudo apt update
  sudo apt install nginx -y
  sudo systemctl start nginx
  sudo systemctl enable nginx
}

# Ana fonksiyon
main_nginx() {
  detect_os
  add_nginx_repo
  install_nginx
}

# Ana fonksiyonu çalıştırma
main_nginx

# Varsayılan Nginx yapılandırmasını ve varsayılan web içeriğini kaldırma
print_msg $YB "Varsayılan Nginx yapılandırmasını ve varsayılan web içeriğini siliniyor..."
rm -rf /etc/nginx/conf.d/default.conf >> /dev/null 2>&1
rm -rf /etc/nginx/sites-enabled/default >> /dev/null 2>&1
rm -rf /etc/nginx/sites-available/default >> /dev/null 2>&1
rm -rf /var/www/html/* >> /dev/null 2>&1
sudo systemctl restart nginx
check_success "Varsayılan Nginx yapılandırması ve varsayılan web içeriği silinemedi."

# Xray için dizin oluşturma
print_msg $YB "Xray için dizin oluşturuluyor..."
mkdir -p /var/www/html/xray >> /dev/null 2>&1
check_success "Xray için dizin oluşturulamadı."

# Tamamlama mesajı
print_msg $GB "Nginx ve yapılandırması tamamlandı."
sleep 3
clear
systemctl restart nginx
systemctl stop nginx
systemctl stop xray
mkdir -p /usr/local/etc/xray/config >> /dev/null 2>&1
mkdir -p /usr/local/etc/xray/dns >> /dev/null 2>&1
touch /usr/local/etc/xray/dns/domain

# Cloudflare API kimlik bilgilerini ayarlama
API_EMAIL="guzelim.batmanli@gmail.com"
API_KEY="4aa140cf85fde3adadad1856bdf67cf5ad460"

# DNS kayıt detaylarını ayarlama
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

# Alan adı isteyen fonksiyon
input_domain() {
    while true; do
        echo -e "${YB}Alan adı girin${NC}"
        echo " "
        read -rp $'\e[33;1mAlan adınızı girin: \e[0m' -e dns

        if [ -z "$dns" ]; then
            echo -e "${RB}Alan adı girilmedi!${NC}"
        elif ! validate_domain "$dns"; then
            echo -e "${RB}Alan adı geçersiz! Lütfen geçerli bir alan adı girin.${NC}"
        else
            echo "$dns" > /usr/local/etc/xray/dns/domain
            echo "DNS=$dns" > /var/lib/dnsvps.conf
            echo -e "Alan adı ${GB}${dns}${NC} başarıyla kaydedildi"
            break
        fi
    done
}

# Alan ID'yi alma fonksiyonu
get_zone_id() {
  echo -e "${YB}Alan ID alınıyor...${NC}"
  ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ "$ZONE_ID" == "null" ]; then
    echo -e "${RB}Alan ID alınamadı${NC}"
    exit 1
  fi

  # Alan ID'yi sensörleme (sadece ilk 3 karakteri ve son 3 karakteri göster)
  ZONE_ID_SENSORED="${GB}${ZONE_ID:0:3}*****${ZONE_ID: -3}"

  echo -e "${YB}Alan ID: $ZONE_ID_SENSORED${NC}"
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

# Alan adına sahip kayıtları kaldırma fonksiyonu
delete_record() {
  local record_name=$1
  local record_type=$2
  local zone_id=${3:-$ZONE_ID}

  RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=$record_type&name=$record_name" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ "$RECORD_ID" != "null" ]; then
    echo -e "${YB}Kayıt siliniyor: ${CB}$record_name${NC} ${YB}.....${NC}"
    response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$RECORD_ID" \
      -H "X-Auth-Email: $API_EMAIL" \
      -H "X-Auth-Key: $API_KEY" \
      -H "Content-Type: application/json")
    handle_response "$response" "${YB}Kayıt silindi:${NC} ${CB}$record_name${NC}"
  fi
}

# IP adresine göre DNS kayıtlarını kaldırma fonksiyonu
delete_records_based_on_ip() {
  echo -e "${YB}IP adresine göre DNS kayıtları siliniyor: ${CB}$IP_ADDRESS${NC} ${YB}.....${NC}"

  # Tüm DNS kayıtlarını alma
  dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $API_EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    -H "Content-Type: application/json")

  # A kayıtlarını ve ilgili CNAME kayıtlarını çözümleme ve kaldırma
  echo "$dns_records" | jq -c '.result[] | select(.type == "A" and .content == "'"$IP_ADDRESS"'")' | while read -r record; do
    record_name=$(echo "$record" | jq -r '.name')
    delete_record "$record_name" "A"
    # İlgili CNAME kayıtlarını kaldırma
    cname_record=$(echo "$dns_records" | jq -c '.result[] | select(.type == "CNAME" and .content == "'"$record_name"'")')
    if [ -n "$cname_record" ]; then
      cname_record_name=$(echo "$cname_record" | jq -r '.name')
      delete_record "$cname_record_name" "CNAME"
    fi
  done
}

# A kayıtı ekleme fonksiyonu
create_A_record() {
  echo -e "${YB}A kayıtı eklendi: $GB$NAME_A$NC $YB.....${NC}"
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
  handle_response "$response" "${YB}A kayıtı eklendi: $GB$NAME_A$NC"
}

# CNAME kayıtı ekleme fonksiyonu
create_CNAME_record() {
  echo -e "${YB}CNAME kayıtı eklendi: $GB$NAME_CNAME$NC $YB.....${NC}"
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
  handle_response "$response" "${YB}CNAME kayıtı eklendi: $GB$NAME_CNAME$NC"
}

# Alan adına sahip kayıt olup olmadığını kontrol etme fonksiyonu
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

# acme.sh'yi kurma ve sertifika alma fonksiyonu
install_acme_sh() {
    domain=$(cat /usr/local/etc/xray/dns/domain)
    rm -rf ~/.acme.sh/*_ecc >> /dev/null 2>&1
    export CF_Email="guzelim.batmanli@gmail.com"
    export CF_Key="4aa140cf85fde3adadad1856bdf67cf5ad460"
    curl https://get.acme.sh | sh
    source ~/.bashrc
    ~/.acme.sh/acme.sh --register-account -m $(echo $RANDOM | md5sum | head -c 6; echo;)@gmail.com --server letsencrypt
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $domain -d *.$domain --listen-v6 --server letsencrypt --keylength ec-256 --fullchain-file /usr/local/etc/xray/fullchain.cer --key-file /usr/local/etc/xray/private.key --reloadcmd "systemctl restart nginx" --force
    chmod 745 /usr/local/etc/xray/private.key
    echo -e "${YB}SSL sertifikası başarıyla kuruldu!${NC}"
}

install_acme_sh2() {
    domain=$(cat /usr/local/etc/xray/dns/domain)
    rm -rf ~/.acme.sh/*_ecc >> /dev/null 2>&1
    curl https://get.acme.sh | sh
    source ~/.bashrc
    ~/.acme.sh/acme.sh --register-account -m $(echo $RANDOM | md5sum | head -c 6; echo;)@gmail.com --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d $domain --standalone --listen-v6 --server letsencrypt --keylength ec-256 --fullchain-file /usr/local/etc/xray/fullchain.cer --key-file /usr/local/etc/xray/private.key --reloadcmd "systemctl restart nginx" --force
    chmod 745 /usr/local/etc/xray/private.key
    echo -e "${YB}SSL sertifikası başarıyla kuruldu!${NC}"
}

# Ana menü fonksiyonu
setup_domain() {
    while true; do
        clear

        # Başlık
        echo -e "${BB}————————————————————————————————————————————————————————"
        echo -e "${YB}                      SETUP DOMAIN"
        echo -e "${BB}————————————————————————————————————————————————————————"

        # Kullanıcı seçeneklerini gösterme
        echo -e "${YB}Seçenekleri:"
        echo -e "${WB}1. Kullanılabilir alan adı kullan"
        echo -e "${WB}2. Özel alan adı kullan"

        # Kullanıcıdan seçim alma
        read -rp $'\e[33;1mSeçiminizi girin: \e[0m' choice

        # Kullanıcı seçimini işleme
        case $choice in
            1)
                while true; do
                    echo -e "${YB}Alanınızı seçin:"
                    echo -e "${WB}1. vless.sbs"
                    echo -e "${WB}2. airi.buzz"
                    echo -e "${WB}3. balrog.cfd${NC}"
                    echo -e " "
                    echo -e "${GB}4. geri${NC}"
                    read -rp $'\e[33;1mSeçiminizi girin: \e[0m' domain_choice
                    case $domain_choice in
                        1)
                            DOMAIN="vless.sbs"
                            ;;
                        2)
                            DOMAIN="airi.buzz"
                            ;;
                        3)
                            DOMAIN="balrog.cfd"
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
                        echo -e "${YB}DNS için adı seçin:"
                        echo -e "${WB}1. Rastgele ad oluştur"
                        echo -e "${WB}2. Özel ad oluştur${NC}"
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
                                install_acme_sh
                                return
                                ;;
                            2)
                                while true; do
                                    read -rp $'\e[33;1mÖzel adınızı girin (sadece küçük harf ve rakam, boşluk içermeyin): \e[0m' custom_dns_name
                                    if [[ ! "$custom_dns_name" =~ ^[a-z0-9-]+$ ]]; then
                                        echo -e "${RB}Alan adı sadece küçük harf ve rakam içermeli, boşluk içermemeli!${NC}"
                                        sleep 2
                                        continue
                                    fi
                                    if [ -z "$custom_dns_name" ]; then
                                        echo -e "${RB}Alan adı boş bırakılmamalı!${NC}"
                                        sleep 2
                                        continue
                                    fi
                                    NAME_A="$custom_dns_name.$DOMAIN"
                                    NAME_CNAME="*.$NAME_A"
                                    TARGET_CNAME="$NAME_A"

                                    get_zone_id
                                    if check_dns_record "$NAME_A" "$ZONE_ID"; then
                                        echo -e "${RB}Alan adı zaten var! Lütfen tekrar deneyin.${NC}"
                                        sleep 2
                                    else
                                        # get_zone_id
                                        delete_records_based_on_ip
                                        create_A_record
                                        create_CNAME_record
                                        install_acme_sh
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
                install_acme_sh2
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

# install_acme_sh fonksiyonunu çağırarak acme.sh'yi kurma ve sertifika alma
#install_acme_sh
#install_acme_sh2

# Ana menüyü çalıştırma
setup_domain

echo -e "${GB}[ INFO ]${NC} ${YB}Nginx & Xray Config Setup${NC}"
# UUID oluşturma
uuid=$(cat /proc/sys/kernel/random/uuid)

# Rastgele şifre oluşturma
pwtr=$(openssl rand -hex 4)
pwss=$(echo $RANDOM | md5sum | head -c 6; echo;)

# Kullanıcı ve sunucu için PSK (Pre-Shared Key) oluşturma
userpsk=$(openssl rand -base64 32)
serverpsk=$(openssl rand -base64 32)
echo "$serverpsk" > /usr/local/etc/xray/serverpsk

# Xray-core'u yapılandırma
print_msg $YB "Xray-core'u yapılandırma..."
XRAY_CONFIG=raw.githubusercontent.com/muzaffer72/1tiklaxraykurulumu/main/config
wget -q -O /usr/local/etc/xray/config/00_log.json "https://${XRAY_CONFIG}/00_log.json"
wget -q -O /usr/local/etc/xray/config/01_api.json "https://${XRAY_CONFIG}/01_api.json"
wget -q -O /usr/local/etc/xray/config/02_dns.json "https://${XRAY_CONFIG}/02_dns.json"
wget -q -O /usr/local/etc/xray/config/03_policy.json "https://${XRAY_CONFIG}/03_policy.json"
cat > /usr/local/etc/xray/config/04_inbounds.json << END
{
    "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
# XTLS
    {
      "listen": "::",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "flow": "xtls-rprx-vision",
            "id": "$uuid"
#xtls
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "alpn": "h2",
            "dest": 4443,
            "xver": 2
          },
          {
            "dest": 8080,
            "xver": 2
          },
          // Websocket
          {
            "path": "/vless-ws",
            "dest": "@vless-ws",
            "xver": 2
          },
          {
            "path": "/vmess-ws",
            "dest": "@vmess-ws",
            "xver": 2
          },
          {
            "path": "/trojan-ws",
            "dest": "@trojan-ws",
            "xver": 2
          },
          {
            "path": "/ss-ws",
            "dest": 1000,
            "xver": 2
          },
          {
            "path": "/ss22-ws",
            "dest": 1100,
            "xver": 2
          },
          // HTTPupgrade
          {
            "path": "/vless-hup",
            "dest": "@vl-hup",
            "xver": 2
          },
          {
            "path": "/vmess-hup",
            "dest": "@vm-hup",
            "xver": 2
          },
          {
            "path": "/trojan-hup",
            "dest": "@tr-hup",
            "xver": 2
          },
          {
            "path": "/ss-hup",
            "dest": "3010",
            "xver": 2
          },
          {
            "path": "/ss22-hup",
            "dest": "3100",
            "xver": 2
          }
        ]
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "tlsSettings": {
          "certificates": [
            {
              "ocspStapling": 3600,
              "certificateFile": "/usr/local/etc/xray/fullchain.cer",
              "keyFile": "/usr/local/etc/xray/private.key"
            }
          ],
          "minVersion": "1.2",
          "cipherSuites": "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
          "alpn": [
            "h2",
            "http/1.1"
          ]
        },
        "network": "tcp",
        "security": "tls"
      },
      "tag": "in-01"
    },
# TROJAN TCP TLS
    {
      "listen": "127.0.0.1",
      "port": 4443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$pwtr"
#trojan
          }
        ],
        "fallbacks": [
          {
            "dest": "8443",
            "xver": 2
          }
        ]
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "tcpSettings": {
          "acceptProxyProtocol": true
        },
        "network": "tcp",
        "security": "none"
      },
      "tag": "in-02"
    },
# VLESS WS
    {
      "listen": "@vless-ws",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "email":"general@vless-ws",
            "id": "$uuid"
#vless
          }
        ],
        "decryption": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vless-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-03"
    },
# VMESS WS
    {
      "listen": "@vmess-ws",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "email": "general@vmess-ws", 
            "id": "$uuid"
#vmess
          }
        ]
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vmess-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-04"
    },
# TROJAN WS
    {
      "listen": "@trojan-ws",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$pwtr"
#trojan
          }
        ]
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojan-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-05"
    },
# SS WS
    {
      "listen": "127.0.0.1",
      "port": 1000,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
            {
              "method": "aes-256-gcm",
              "password": "$pwss"
#ss
            }
          ],
        "network": "tcp,udp"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-06"
    },
# SS2022 WS
    {
      "listen": "127.0.0.1",
      "port": 1100,
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "$(cat /usr/local/etc/xray/serverpsk)",
        "clients": [
          {
            "password": "$userpsk"
#ss22
          }
        ],
        "network": "tcp,udp"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss22-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-07"
    },
# VLESS HTTPupgrade
    {
      "listen": "@vl-hup",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "email":"general@vless-ws",
            "id": "$uuid"
#vless
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/vless-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-08"
    },
# VMESS HTTPupgrade
    {
      "listen": "@vm-hup",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "email":"general@vless-ws",
            "id": "$uuid"
#vmess
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/vmess-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-09"
    },
# TROJAN HTTPupgrade
    {
      "listen": "@tr-hup",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$pwtr"
#trojan
          }
        ]
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojan-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-10"
    },
# SS HTTPupgrade
    {
      "listen": "127.0.0.1",
      "port": "3010",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
            {
              "method": "aes-256-gcm",
              "password": "$pwss"
#ss
            }
          ],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-11"
    },
# SS2022 HTTPupgrade
    {
      "listen": "127.0.0.1",
      "port": "3100",
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "$(cat /usr/local/etc/xray/serverpsk)",
        "clients": [
          {
            "password": "$userpsk"
#ss22
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss22-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-12"
    },
# VLESS gRPC
    {
      "listen": "127.0.0.1",
      "port": 5000,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "email": "grpc",
            "id": "$uuid"
#vless
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "grpcSettings": {
          "multiMode": true,
          "serviceName": "vless-grpc",
          "alpn": [
            "h2",
            "http/1.1"
          ]
        },
        "network": "grpc",
        "security": "none"
      },
      "tag": "in-13"
    },
# VMESS gRPC
    {
      "listen": "127.0.0.1",
      "port": 5100,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "email": "grpc",
            "id": "$uuid"
#vmess
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "grpcSettings": {
          "multiMode": true,
          "serviceName": "vmess-grpc",
          "alpn": [
            "h2",
            "http/1.1"
          ]
        },
        "network": "grpc",
        "security": "none"
      },
      "tag": "in-14"
    },
# TROJAN gRPC
    {
      "listen": "127.0.0.1",
      "port": 5200,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "email": "grpc",
            "password": "$pwtr"
#trojan
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "grpcSettings": {
          "multiMode": true,
          "serviceName": "trojan-grpc",
          "alpn": [
            "h2",
            "http/1.1"
          ]
        },
        "network": "grpc",
        "security": "none"
      },
      "tag": "in-15"
    },
# SS gRPC
    {
      "listen": "127.0.0.1",
      "port": 5300,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
            {
              "method": "aes-256-gcm",
              "password": "$pwss"
#ss
            }
          ],
        "network": "tcp,udp"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "grpcSettings": {
          "multiMode": true,
          "serviceName": "ss-grpc",
          "alpn": [
            "h2",
            "http/1.1"
          ]
        },
        "network": "grpc",
        "security": "none"
      },
      "tag": "in-16"
    },
# SS2022 gRPC
    {
      "listen": "127.0.0.1",
      "port": 5400,
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "$(cat /usr/local/etc/xray/serverpsk)",
        "clients": [
          {
            "password": "$userpsk"
#ss22
          }
        ],
        "network": "tcp,udp"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "grpcSettings": {
          "multiMode": true,
          "serviceName": "ss22-grpc",
          "alpn": [
            "h2",
            "http/1.1"
          ]
        },
        "network": "grpc",
        "security": "none"
      },
      "tag": "in-17"
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$uuid"
#universal
          }
        ],
        "fallbacks": [
          {
            "dest": 8080,
            "xver": 2
          },
          // Websocket
          {
            "path": "/vless-ws",
            "dest": "@vless-ws",
            "xver": 2
          },
          {
            "path": "/vmess-ws",
            "dest": "@vmess-ws",
            "xver": 2
          },
          {
            "path": "/trojan-ws",
            "dest": "@trojan",
            "xver": 2
          },
          {
            "dest": 2000,
            "xver": 2
          },
          {
            "dest": 2100,
            "xver": 2
          },
          // HTTPupgrade
          {
            "path": "/vless-hup",
            "dest": "@vl-hup",
            "xver": 2
          },
          {
            "path": "/vmess-hup",
            "dest": "@vm-hup",
            "xver": 2
          },
          {
            "path": "/trojan-hup",
            "dest": "@trojan-hup",
            "xver": 2
          },
          {
            "path": "/ss-hup",
            "dest": "4000",
            "xver": 2
          },
          {
            "path": "/ss22-hup",
            "dest": "4100",
            "xver": 2
          }
        ],
        "decryption": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-18"
    },
# TROJAN WS
    {
      "listen": "@trojan",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$pwtr"
#trojan
          }
        ]
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojan-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-19"
    },
# SS WS
    {
      "listen": "127.0.0.1",
      "port": 2000,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
            {
              "method": "aes-256-gcm",
              "password": "$pwss"
#ss
            }
          ],
        "network": "tcp,udp"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-20"
    },
# SS2022 WS
    {
      "listen": "127.0.0.1",
      "port": 2100,
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "$(cat /usr/local/etc/xray/serverpsk)",
        "clients": [
          {
            "password": "$userpsk"
#ss22
          }
        ],
        "network": "tcp,udp"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "streamSettings": {
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss22-ws"
        },
        "network": "ws",
        "security": "none"
      },
      "tag": "in-21"
    },
# TROJAN HTTPupgrade
    {
      "listen": "@trojan-hup",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$pwtr"
#trojan
          }
        ]
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojan-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-22"
    },
# SS HTTPupgrade
    {
      "listen": "127.0.0.1",
      "port": 4000,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
            {
              "method": "aes-256-gcm",
              "password": "$pwss"
#ss
            }
          ],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-23"
    },
# SS2022 HTTPupgrade
    {
      "listen": "127.0.0.1",
      "port": "4100",
      "protocol": "shadowsocks",
      "settings": {
        "method": "2022-blake3-aes-256-gcm",
        "password": "$(cat /usr/local/etc/xray/serverpsk)",
        "clients": [
          {
            "password": "$userpsk"
#ss22
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/ss22-hup"
        },
        "network": "httpupgrade",
        "security": "none"
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "in-24"
    }
  ]
}
END
wget -q -O /usr/local/etc/xray/config/05_outbonds.json "https://${XRAY_CONFIG}/05_outbonds.json"
wget -q -O /usr/local/etc/xray/config/06_routing.json "https://${XRAY_CONFIG}/06_routing.json"
wget -q -O /usr/local/etc/xray/config/07_stats.json "https://${XRAY_CONFIG}/07_stats.json"
sleep 1.5

# Xray için gerekli log dosyasını oluşturma
print_msg $YB "Xray için gerekli log dosyası oluşturuluyor..."
sudo touch /var/log/xray/access.log /var/log/xray/error.log
sudo chown nobody:nogroup /var/log/xray/access.log /var/log/xray/error.log
sudo chmod 664 /var/log/xray/access.log /var/log/xray/error.log
check_success "Xray için gerekli log dosyası oluşturulamadı."
sleep 1.5

# Nginx'i yapılandırma
print_msg $YB "Nginx'i yapılandırma..."
wget -q -O /var/www/html/index.html https://raw.githubusercontent.com/muzaffer72/1tiklaxraykurulumu/main/index.html
wget -q -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/muzaffer72/1tiklaxraykurulumu/main/nginx.conf
domain=$(cat /usr/local/etc/xray/dns/domain)
sed -i "s/server_name web.com;/server_name $domain;/g" /etc/nginx/nginx.conf
sed -i "s/server_name \*.web.com;/server_name \*.$domain;/" /etc/nginx/nginx.conf
# Eğer buraya kadar hata yoksa, yapılandırma başarılı
print_msg $GB "Xray-core ve Nginx yapılandırması başarılı."
sleep 3
systemctl restart nginx
systemctl restart xray
echo -e "${GB}[ INFO ]${NC} ${YB}Setup Done${NC}"
sleep 3
clear

# Torrent trafiğini engelleme (BitTorrent)
sudo iptables -A INPUT -p udp --dport 6881:6889 -j DROP
sudo iptables -A INPUT -p tcp --dport 6881:6889 -j DROP
# Torrent trafiğini string modülü ile engelleme
sudo iptables -A INPUT -p tcp --dport 6881:6889 -m string --algo bm --string "BitTorrent" -j DROP
sudo iptables -A INPUT -p udp --dport 6881:6889 -m string --algo bm --string "BitTorrent" -j DROP
cd /usr/bin
GITHUB=raw.githubusercontent.com/muzaffer72/1tiklaxraykurulumu/main/
echo -e "${GB}[ INFO ]${NC} ${YB}Ana menü indiriliyor...${NC}"
wget -q -O menu "https://${GITHUB}/menu/menu.sh"
wget -q -O allxray "https://${GITHUB}/menu/allxray.sh"
wget -q -O del-xray "https://${GITHUB}/xray/del-xray.sh"
wget -q -O extend-xray "https://${GITHUB}/xray/extend-xray.sh"
wget -q -O create-xray "https://${GITHUB}/xray/create-xray.sh"
wget -q -O cek-xray "https://${GITHUB}/xray/cek-xray.sh"
wget -q -O route-xray "https://${GITHUB}/xray/route-xray.sh"
wget -q -O system_info.py "https://${GITHUB}/system_info.py"
wget -q -O traffic.py "https://${GITHUB}/traffic.py"
sleep 0.5
sleep 0.5

echo -e "${GB}[ INFO ]${NC} ${YB}Diğer menüler indiriliyor...${NC}"
wget -q -O xp "https://${GITHUB}/other/xp.sh"
wget -q -O dns "https://${GITHUB}/other/dns.sh"
wget -q -O certxray "https://${GITHUB}/other/certxray.sh"
wget -q -O about "https://${GITHUB}/other/about.sh"
wget -q -O clear-log "https://${GITHUB}/other/clear-log.sh"
wget -q -O log-xray "https://${GITHUB}/other/log-xray.sh"
wget -q -O update-xray "https://${GITHUB}/other/update-xray.sh"

echo -e "${GB}[ INFO ]${NC} ${YB}İzin vermek için betikleri çalıştırın...${NC}"
chmod +x del-xray extend-xray create-xray cek-xray log-xray menu allxray xp dns certxray about clear-log update-xray route-xray
echo -e "${GB}[ INFO ]${NC} ${YB}Hazırlık tamamlandı.${NC}"
sleep 3
cd
echo "0 0 * * * root xp" >> /etc/crontab
echo "*/3 * * * * root clear-log" >> /etc/crontab
systemctl restart cron
clear
echo ""
echo -e "${BB}—————————————————————————————————————————————————————————${NC}"
echo -e "                  ${WB}BU SCRİPT ONVAO.NET TARAFINDAN GÜNCELLEŞTİRİLİYOR${NC}"
echo -e "${BB}—————————————————————————————————————————————————————————${NC}"
echo -e "                 ${WB}»»» Protocol Service «««${NC}  "
echo -e "${BB}—————————————————————————————————————————————————————————${NC}"
echo -e "${YB}Vmess Websocket${NC}     : ${YB}443 & 80${NC}"
echo -e "${YB}Vmess HTTPupgrade${NC}   : ${YB}443 & 80${NC}"
echo -e "${YB}Vmess gRPC${NC}          : ${YB}443${NC}"
echo ""
echo -e "${YB}Vless XTLS-Vision${NC}   : ${YB}443${NC}"
echo -e "${YB}Vless Websocket${NC}     : ${YB}443 & 80${NC}"
echo -e "${YB}Vless HTTPupgrade${NC}   : ${YB}443 & 80${NC}"
echo -e "${YB}Vless gRPC${NC}          : ${YB}443${NC}"
echo ""
echo -e "${YB}Trojan TCP TLS${NC}      : ${YB}443${NC}"
echo -e "${YB}Trojan Websocket${NC}    : ${YB}443 & 80${NC}"
echo -e "${YB}Trojan HTTPupgrade${NC}  : ${YB}443 & 80${NC}"
echo -e "${YB}Trojan gRPC${NC}         : ${YB}443${NC}"
echo ""
echo -e "${YB}SS Websocket${NC}        : ${YB}443 & 80${NC}"
echo -e "${YB}SS HTTPupgrade${NC}      : ${YB}443 & 80${NC}"
echo -e "${YB}SS gRPC${NC}             : ${YB}443${NC}"
echo ""
echo -e "${YB}SS 2022 Websocket${NC}   : ${YB}443 & 80${NC}"
echo -e "${YB}SS 2022 HTTPupgrade${NC} : ${YB}443 & 80${NC}"
echo -e "${YB}SS 2022 gRPC${NC}        : ${YB}443${NC}"
echo -e "${BB}————————————————————————————————————————————————————————${NC}"
echo ""
rm -f install.sh
secs_to_human "$(($(date +%s) - ${start}))"
echo -e "${YB}[ WARNING ] reboot now ? (Y/N)${NC} "
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
exit 0
else
reboot
fi
