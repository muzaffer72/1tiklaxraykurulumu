#!/bin/bash

clear
# Metin renkleri
NC='\e[0m'       # Renksiz (metin rengini varsayılana sıfırlar)
DEFBOLD='\e[39;1m' # Varsayılan Kalın
RB='\e[31;1m'    # Kırmızı Kalın
GB='\e[32;1m'    # Yeşil Kalın
YB='\e[33;1m'    # Sarı Kalın
BB='\e[34;1m'    # Mavi Kalın
MB='\e[35;1m'    # Magenta Kalın
CB='\e[36;1m'    # Cyan Kalın
WB='\e[37;1m'    # Beyaz Kalın

# Renkli mesaj yazdırma fonksiyonu
print_msg() {
    COLOR=$1
    MSG=$2
    echo -e "${COLOR}${MSG}${NC}"
}

# Linux OS'unu algılama fonksiyonu
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        print_msg $RB "İşletim sistemi algılanamadı. Bu betik yalnızca Debian ve Red Hat tabanlı dağıtımları destekler."
        exit 1
    fi
}

# En son Xray-core sürümünü kontrol etme fonksiyonu
get_latest_xray_version() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name')
    if [ -z "$LATEST_VERSION" ]; then
        print_msg $RB "En son Xray-core sürümü bulunamadı."
        exit 1
    fi
}

# Xray-core kurma fonksiyonu
install_xray_core() {
    # Etkileşimli mesaj gösterme
    print_msg $YB "Xray-core kurulumu hazırlanıyor..."
    read -p "Devam etmek için Enter tuşuna basın..."

    # Mimarinin algılanması
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

    # Xray-core indirme ve kurma
    print_msg $YB "En son Xray-core sürümü indiriliyor ve kuruluyor..."
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/$LATEST_VERSION/Xray-linux-$ARCH.zip"
    curl -sL -o xray.zip $DOWNLOAD_URL
    unzip -oq xray.zip -d /usr/local/bin
    rm -f xray.zip

    # Çalıştırma izni verme
    chmod +x /usr/local/bin/xray

    # Tamamlama mesajı gösterme
    print_msg $YB "Xray-core sürüm $GB$LATEST_VERSION$NC$YB başarıyla kuruldu."
}

# İşlemi başlatma
print_msg $YB "Kullanılan Linux OS'u algılanıyor..."
detect_os

# OS bilgisini gösterme
print_msg $YB "Kullanılan Linux OS: $GB$OS $VERSION"

# OS'un desteklenip desteklenmediğini kontrol etme
if [[ "$OS" == "Ubuntu" || "$OS" == "Debian" || "$OS" == "CentOS" || "$OS" == "Fedora" || "$OS" == "Red Hat Enterprise Linux" ]]; then
    print_msg $YB "En son Xray-core sürümü kontrol ediliyor..."
else
    print_msg $RB "$OS dağıtımı bu betik tarafından desteklenmiyor. Kurulum işlemi iptal edildi."
    exit 1
fi

# En son Xray-core sürümünü kontrol etme
get_latest_xray_version
print_msg $YB "En son Xray-core sürümü: $GB$LATEST_VERSION"

# Xray-core kurma
install_xray_core
systemctl restart xray

# Ana menüye dönmeden önce kullanıcıdan herhangi bir tuşa basmasını isteme
read -n 1 -s -r -p "Ana menüye dönmek için herhangi bir tuşa basın..."
menu