#!/bin/bash

# Renk Tanımları
NC='\e[0m'
DEFBOLD='\e[39;1m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'
BB='\e[34;1m'
MB='\e[35;1m'
CB='\e[36;1m'
WB='\e[37;1m'

# Rastgele dize oluşturma fonksiyonu
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$1" | head -n 1
}

# UUID oluşturma fonksiyonu
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# Xray yapılandırmasına bölüm ekleme fonksiyonu
add_xray_config() {
    local section=$1
    local content=$2
    sed -i "/#$section\$/a\\#&@ $user $exp\n$content" /usr/local/etc/xray/config/04_inbounds.json
}

# Değişkenlerin Başlatılması
user=$(generate_random_string 7)
domain=$(cat /usr/local/etc/xray/dns/domain)
cipher="aes-256-gcm"
cipher2="2022-blake3-aes-256-gcm"
uuid=$(generate_uuid)
pwtr=$(openssl rand -hex 4)
pwss=$(echo $RANDOM | md5sum | head -c 6)
userpsk=$(openssl rand -base64 32)
serverpsk=$(cat /usr/local/etc/xray/serverpsk)

echo -e "${BB}————————————————————————————————————————————————————————${NC}"

valid_input=false

while [ "$valid_input" = false ]; do
    read -p "Aktif Süre / Kullanım Süresi (gün): " masaaktif

    # Girdinin sadece sayılardan oluştuğunu kontrol etme
    if [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
        valid_input=true
    else
        echo -e "${RB}Girdi sadece sayı olmalıdır. Lütfen tekrar deneyin.${NC}"
    fi
done

echo -e "${BB}————————————————————————————————————————————————————————${NC}"
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# Xray Yapılandırma Dosyasına Ekleme
add_xray_config "xtls" "},{\"flow\": \"xtls-rprx-vision\",\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "vless" "},{\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "universal" "},{\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "vmess" "},{\"id\": \"$uuid\",\"email\": \"$user\""
add_xray_config "trojan" "},{\"password\": \"$pwtr\",\"email\": \"$user\""
add_xray_config "ss" "},{\"password\": \"$pwss\",\"method\": \"$cipher\",\"email\": \"$user\""
add_xray_config "ss22" "},{\"password\": \"$userpsk\",\"email\": \"$user\""

ISP=$(cat /usr/local/etc/xray/org)
CITY=$(cat /usr/local/etc/xray/city)
REG=$(cat /usr/local/etc/xray/region)

# Vmess bağlantı linki oluşturma fonksiyonu
create_vmess_link() {
    local version="2"
    local ps=$1
    local port=$2
    local net=$3
    local path=$4
    local tls=$5
    cat <<EOF | base64 -w 0
{
"v": "$version",
"ps": "$ps",
"add": "$domain",
"port": "$port",
"id": "$uuid",
"aid": "0",
"net": "$net",
"path": "$path",
"type": "none",
"host": "$domain",
"tls": "$tls"
}
EOF
}

# Vmess Bağlantıları Oluşturma
vmesslink1="vmess://$(create_vmess_link "vmess-ws-tls" "443" "ws" "/vmess-ws" "tls")"
vmesslink2="vmess://$(create_vmess_link "vmess-ws-ntls" "80" "ws" "/vmess-ws" "none")"
vmesslink3="vmess://$(create_vmess_link "vmess-hup-tls" "443" "httpupgrade" "/vmess-hup" "tls")"
vmesslink4="vmess://$(create_vmess_link "vmess-hup-ntls" "80" "httpupgrade" "/vmess-hup" "none")"
vmesslink5="vmess://$(create_vmess_link "vmess-grpc" "443" "grpc" "vmess-grpc" "tls")"

# Vless Bağlantıları Oluşturma
vlesslink1="vless://$uuid@$domain:443?path=/vless-ws&security=tls&encryption=none&host=$domain&type=ws&sni=$domain#vless-ws-tls"
vlesslink2="vless://$uuid@$domain:80?path=/vless-ws&security=none&encryption=none&host=$domain&type=ws#vless-ws-ntls"
vlesslink3="vless://$uuid@$domain:443?path=/vless-hup&security=tls&encryption=none&host=$domain&type=httpupgrade&sni=$domain#vless-hup-tls"
vlesslink4="vless://$uuid@$domain:80?path=/vless-hup&security=none&encryption=none&host=$domain&type=httpupgrade#vless-hup-ntls"
vlesslink5="vless://$uuid@$domain:443?security=tls&encryption=none&headerType=gun&type=grpc&serviceName=vless-grpc&sni=$domain#vless-grpc"
vlesslink6="vless://$uuid@$domain:443?security=tls&encryption=none&headerType=none&type=tcp&sni=$domain&flow=xtls-rprx-vision#vless-vision"

# Trojan Bağlantıları Oluşturma
trojanlink1="trojan://$pwtr@$domain:443?path=/trojan-ws&security=tls&host=$domain&type=ws&sni=$domain#trojan-ws-tls"
trojanlink2="trojan://$pwtr@$domain:80?path=/trojan-ws&security=none&host=$domain&type=ws#trojan-ws-ntls"
trojanlink3="trojan://$pwtr@$domain:443?path=/trojan-hup&security=tls&host=$domain&type=httpupgrade&sni=$domain#trojan-hup-tls"
trojanlink4="trojan://$pwtr@$domain:80?path=/trojan-hup&security=none&host=$domain&type=httpupgrade#trojan-hup-ntls"
trojanlink5="trojan://$pwtr@$domain:443?security=tls&type=grpc&mode=multi&serviceName=trojan-grpc&sni=$domain#trojan-grpc"
trojanlink6="trojan://$pwtr@$domain:443?security=tls&type=tcp&sni=$domain#trojan-tcp-tls"

# Shadowsocks Bağlantıları Oluşturma
encode_ss() {
    echo -n "$1:$2" | base64 -w 0
}

ss_base64=$(encode_ss "$cipher" "$pwss")
sslink1="ss://${ss_base64}@$domain:443?path=/ss-ws&security=tls&host=${domain}&type=ws&sni=${domain}#ss-ws-tls"
sslink2="ss://${ss_base64}@$domain:80?path=/ss-ws&security=none&host=${domain}&type=ws#ss-ws-ntls"
sslink3="ss://${ss_base64}@$domain:443?path=/ss-hup&security=tls&host=${domain}&type=httpupgrade&sni=${domain}#ss-hup-tls"
sslink4="ss://${ss_base64}@$domain:80?path=/ss-hup&security=none&host=${domain}&type=httpupgrade#ss-hup-ntls"
sslink5="ss://${ss_base64}@$domain:443?security=tls&encryption=none&type=grpc&serviceName=ss-grpc&sni=$domain#ss-grpc"

ss2022_base64=$(encode_ss "$cipher2" "$serverpsk:$userpsk")
ss22link1="ss://${ss2022_base64}@$domain:443?path=/ss22-ws&security=tls&host=${domain}&type=ws&sni=${domain}#ss2022-ws-tls"
ss22link2="ss://${ss2022_base64}@$domain:80?path=/ss22-ws&security=none&host=${domain}&type=ws#ss2022-ws-ntls"
ss22link3="ss://${ss2022_base64}@$domain:443?path=/ss22-hup&security=tls&host=${domain}&type=httpupgrade&sni=${domain}#ss2022-hup-tls"
ss22link4="ss://${ss2022_base64}@$domain:80?path=/ss22-hup&security=none&host=${domain}&type=httpupgrade#ss2022-hup-ntls"
ss22link5="ss://${ss2022_base64}@$domain:443?security=tls&encryption=none&type=grpc&serviceName=ss22-grpc&sni=$domain#ss2022-grpc"

# Menulis Log ke File
cat > /var/www/html/xray/xray-$user.html << END
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Onvao.net Bağlantı yönetimi</title>
    <link href="https://fonts.googleapis.com/css2?family=Google+Sans&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
    <style>
        html, body {
            height: 100%;
            margin: 0;
            padding: 0;
            font-family: 'Google Sans', sans-serif;
            background-color: #0a0e17;
            color: #ffffff;
            overflow-x: hidden;
        }

        body {
            background: linear-gradient(125deg, #0a0e17, #152238);
            min-height: 100vh;
        }

        /* Arka plan animasyonu */
        .bg-animation {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: -1;
            overflow: hidden;
        }

        .network-grid {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-image: 
              radial-gradient(rgba(33, 150, 243, 0.1) 2px, transparent 2px),
              radial-gradient(rgba(33, 150, 243, 0.1) 2px, transparent 2px);
            background-size: 50px 50px;
            background-position: 0 0, 25px 25px;
            animation: gridAnimation 60s linear infinite;
        }

        @keyframes gridAnimation {
            0% {
                background-position: 0 0, 25px 25px;
            }
            100% {
                background-position: 1000px 0, 1025px 25px;
            }
        }

        .glow-circle {
            position: absolute;
            border-radius: 50%;
            filter: blur(40px);
            opacity: 0.15;
        }

        .glow-circle:nth-child(1) {
            top: 20%;
            left: 20%;
            width: 300px;
            height: 300px;
            background: #1976d2;
            animation: float 15s ease-in-out infinite;
        }

        .glow-circle:nth-child(2) {
            bottom: 15%;
            right: 15%;
            width: 200px;
            height: 200px;
            background: #651fff;
            animation: float 20s ease-in-out infinite reverse;
        }

        .glow-circle:nth-child(3) {
            top: 40%;
            right: 30%;
            width: 150px;
            height: 150px;
            background: #00e5ff;
            animation: float 18s ease-in-out infinite 5s;
        }

        @keyframes float {
            0% { transform: translate(0, 0); }
            50% { transform: translate(-20px, 20px); }
            100% { transform: translate(0, 0); }
        }

        /* Kar efekti stilleri */
        .snowfall {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 0;
            pointer-events: none;
            overflow: hidden;
        }

        /* Havai fişek stilleri */
        .fireworks-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 1;
            overflow: hidden;
        }

        /* Ana içerik */
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 30px 20px;
            position: relative;
            z-index: 2;
        }

        header, footer {
            background: rgba(25, 31, 46, 0.8);
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 24px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            margin-bottom: 30px;
        }

        header h1 {
            color: #fff;
            font-size: 32px;
            margin: 0;
            font-weight: 700;
        }

        .server-info {
            background: rgba(25, 31, 46, 0.8);
            border-radius: 24px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            padding: 25px;
            margin-bottom: 30px;
        }

        h2 {
            color: #fff;
            border-bottom: 2px solid rgba(33, 150, 243, 0.5);
            padding-bottom: 15px;
            margin-bottom: 25px;
            font-size: 24px;
            display: flex;
            align-items: center;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        h2 i {
            color: #2196f3;
            margin-right: 15px;
            font-size: 1.2em;
        }

        h2:hover {
            color: #2196f3;
        }

        pre {
            background-color: rgba(0, 0, 0, 0.3);
            color: #64ffda;
            padding: 20px;
            border-radius: 12px;
            overflow-x: auto;
            font-family: "Courier New", Courier, monospace;
            margin-bottom: 20px;
            border: 1px solid rgba(33, 150, 243, 0.3);
            font-size: 15px;
            line-height: 1.5;
        }

        .section {
            margin-bottom: 40px;
            background: rgba(25, 31, 46, 0.8);
            border-radius: 24px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            padding: 25px;
        }

        .link-section {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
        }

        .link-box {
            flex: 1;
            min-width: 300px;
            max-width: 100%;
            padding: 20px;
            border: 1px solid rgba(33, 150, 243, 0.3);
            border-radius: 15px;
            background-color: rgba(15, 20, 30, 0.6);
            margin-bottom: 20px;
            box-sizing: border-box;
            transition: all 0.3s ease;
        }

        .link-box:hover {
            border-color: rgba(33, 150, 243, 0.7);
            background-color: rgba(15, 20, 30, 0.8);
            transform: translateY(-3px);
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
        }

        .link-box h3 {
            color: #2196f3;
            margin-top: 0;
            font-size: 18px;
            border-bottom: 1px solid rgba(33, 150, 243, 0.3);
            padding-bottom: 10px;
        }

        button, .copy-button {
            display: inline-block;
            padding: 12px 20px;
            border: none;
            background: linear-gradient(135deg, #2196f3, #1976d2);
            color: white;
            border-radius: 50px;
            cursor: pointer;
            margin: 10px 0 0 0;
            font-weight: bold;
            font-size: 16px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(33, 150, 243, 0.3);
        }

        button::before, .copy-button::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            transition: all 0.5s ease;
        }

        button:hover::before, .copy-button:hover::before {
            left: 100%;
        }

        button:hover, .copy-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 20px rgba(33, 150, 243, 0.4);
        }

        .notification {
            display: none;
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(100, 255, 218, 0.9);
            color: #0a0e17;
            padding: 15px 25px;
            border-radius: 50px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
            z-index: 1000;
            font-weight: bold;
            animation: fadeInOut 2s ease;
        }

        @keyframes fadeInOut {
            0% { opacity: 0; transform: translateY(-20px); }
            10% { opacity: 1; transform: translateY(0); }
            90% { opacity: 1; transform: translateY(0); }
            100% { opacity: 0; transform: translateY(-20px); }
        }

        .accordion-content {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.5s ease-out;
        }

        .accordion-content.show {
            max-height: 5000px;
        }

        footer {
            text-align: center;
            padding: 30px 20px;
            margin-top: 40px;
        }

        .footer-content {
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 15px 0;
        }

        .copyright {
            text-align: center;
            margin-bottom: 20px;
            color: rgba(255, 255, 255, 0.8);
            font-size: 16px;
            line-height: 1.6;
        }

        .app-buttons {
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 20px;
            margin: 25px 0;
        }

        .app-button {
            display: inline-flex;
            align-items: center;
            padding: 12px 25px;
            background: linear-gradient(135deg, #2196f3, #1976d2);
            color: white;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
            font-size: 16px;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(33, 150, 243, 0.3);
            position: relative;
            overflow: hidden;
            border: none;
        }

        .app-button::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            transition: all 0.5s ease;
        }

        .app-button:hover::before {
            left: 100%;
        }

        .app-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 20px rgba(33, 150, 243, 0.4);
        }

        .app-button i {
            margin-right: 10px;
            font-size: 1.2em;
        }

        @media (max-width: 768px) {
            .container {
                padding: 15px;
            }
            
            h2 {
                font-size: 20px;
            }
            
            .link-box {
                min-width: 100%;
            }
            
            pre {
                font-size: 13px;
                padding: 15px;
            }
            
            button, .copy-button, .app-button {
                padding: 10px 15px;
                font-size: 14px;
            }
            
            header h1 {
                font-size: 24px;
            }
        }

        @media (max-width: 480px) {
            h2 {
                font-size: 18px;
            }
            
            .section {
                padding: 15px;
            }
            
            .app-buttons {
                flex-direction: column;
                align-items: center;
            }
            
            .app-button {
                width: 100%;
                max-width: 280px;
                justify-content: center;
            }
        }
    </style>
</head>
<body>

    <header>
        <h1>Xray VPN</h1>
    </header>

    <div class="section">
        <h2><i class="fas fa-server"></i> Sunucu Bilgileri</h2>
        <pre>ISP            : ${ISP}
Bölge          : ${REG}
Şehir          : ${CITY}
Port TLS/HTTPS : 443
Port HTTP      : 80
Transport      : XTLS-Vision, TCP TLS, HTTPupgrade, Websocket, gRPC
Bitiş Tarihi   : ${exp}</pre>
    </div>

    <hr>

    <!-- Vmess Links -->
    <div class="section">
        <h2 onclick="toggleAccordion(this)"><i class="fas fa-link"></i> Vmess Bağlantıları</h2>
        <div class="accordion-content">
            <div class="link-section">
                <div class="link-box">
                    <h3>Websocket TLS</h3>
                    <pre id="vmess-ws-tls">${vmesslink1}</pre>
                    <button onclick="copyToClipboard('vmess-ws-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>Websocket non TLS</h3>
                    <pre id="vmess-ws-ntls">${vmesslink2}</pre>
                    <button onclick="copyToClipboard('vmess-ws-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade TLS</h3>
                    <pre id="vmess-hup-tls">${vmesslink3}</pre>
                    <button onclick="copyToClipboard('vmess-hup-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade non TLS</h3>
                    <pre id="vmess-hup-ntls">${vmesslink4}</pre>
                    <button onclick="copyToClipboard('vmess-hup-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>gRPC</h3>
                    <pre id="vmess-grpc">${vmesslink5}</pre>
                    <button onclick="copyToClipboard('vmess-grpc')">Kopyala</button>
                </div>
            </div>
        </div>
    </div>

    <hr>

    <!-- Vless Links -->
    <div class="section">
        <h2 onclick="toggleAccordion(this)"><i class="fas fa-link"></i> Vless Bağlantıları</h2>
        <div class="accordion-content">
            <div class="link-section">
                <div class="link-box">
                    <h3>Websocket TLS</h3>
                    <pre id="vless-ws-tls">${vlesslink1}</pre>
                    <button onclick="copyToClipboard('vless-ws-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>Websocket non TLS</h3>
                    <pre id="vless-ws-ntls">${vlesslink2}</pre>
                    <button onclick="copyToClipboard('vless-ws-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade TLS</h3>
                    <pre id="vless-hup-ntls">${vlesslink3}</pre>
                    <button onclick="copyToClipboard('vless-hup-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade non TLS</h3>
                    <pre id="vless-hup-ntls">${vlesslink4}</pre>
                    <button onclick="copyToClipboard('vless-hup-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>XTLS-RPRX-VISION</h3>
                    <pre id="vless-vision">${vlesslink5}</pre>
                    <button onclick="copyToClipboard('vless-vision')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>gRPC</h3>
                    <pre id="vless-grpc">${vlesslink6}</pre>
                    <button onclick="copyToClipboard('vless-grpc')">Kopyala</button>
                </div>
            </div>
        </div>
    </div>

    <hr>

    <!-- Trojan Links -->
    <div class="section">
        <h2 onclick="toggleAccordion(this)"><i class="fas fa-link"></i> Trojan Bağlantıları</h2>
        <div class="accordion-content">
            <div class="link-section">
                <div class="link-box">
                    <h3>Websocket TLS</h3>
                    <pre id="trojan-ws-tls">${trojanlink1}</pre>
                    <button onclick="copyToClipboard('trojan-ws-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>Websocket non TLS</h3>
                    <pre id="trojan-ws-ntls">${trojanlink2}</pre>
                    <button onclick="copyToClipboard('trojan-ws-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade TLS</h3>
                    <pre id="trojan-hup-tls">${trojanlink3}</pre>
                    <button onclick="copyToClipboard('trojan-hup-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade non TLS</h3>
                    <pre id="trojan-hup-ntls">${trojanlink4}</pre>
                    <button onclick="copyToClipboard('trojan-hup-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>TCP TLS</h3>
                    <pre id="trojan-tcp">${trojanlink5}</pre>
                    <button onclick="copyToClipboard('trojan-tcp')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>gRPC</h3>
                    <pre id="trojan-grpc">${trojanlink6}</pre>
                    <button onclick="copyToClipboard('trojan-grpc')">Kopyala</button>
                </div>
            </div>
        </div>
    </div>

    <hr>

    <!-- Shadowsocks Links -->
    <div class="section">
        <h2 onclick="toggleAccordion(this)"><i class="fas fa-link"></i> Shadowsocks Bağlantıları</h2>
        <div class="accordion-content">
            <div class="link-section">
                <div class="link-box">
                    <h3>Websocket TLS</h3>
                    <pre id="ss-ws-tls">${sslink1}</pre>
                    <button onclick="copyToClipboard('ss-ws-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>Websocket non TLS</h3>
                    <pre id="ss-ws-ntls">${sslink2}</pre>
                    <button onclick="copyToClipboard('ss-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade TLS</h3>
                    <pre id="ss-hup-tls">${sslink3}</pre>
                    <button onclick="copyToClipboard('ss-hup-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade non TLS</h3>
                    <pre id="ss-hup-ntls">${sslink4}</pre>
                    <button onclick="copyToClipboard('ss-hup-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>gRPC</h3>
                    <pre id="ss-grpc">${sslink5}</pre>
                    <button onclick="copyToClipboard('ss-grpc')">Kopyala</button>
                </div>
            </div>
        </div>
    </div>

    <hr>

    <!-- Shadowsocks 2022 Links -->
    <div class="section">
        <h2 onclick="toggleAccordion(this)"><i class="fas fa-link"></i> Shadowsocks 2022 Bağlantıları</h2>
        <div class="accordion-content">
            <div class="link-section">
                <div class="link-box">
                    <h3>Websocket TLS</h3>
                    <pre id="ss2022-ws-tls">${ss22link1}</pre>
                    <button onclick="copyToClipboard('ss2022-ws-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>Websocket non TLS</h3>
                    <pre id="ss2022-ws-ntls">${ss22link2}</pre>
                    <button onclick="copyToClipboard('ss2022-ws-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade TLS</h3>
                    <pre id="ss2022-hup-tls">${ss22link3}</pre>
                    <button onclick="copyToClipboard('ss2022-hup-tls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>HTTPupgrade non TLS</h3>
                    <pre id="ss2022-hup-ntls">${ss22link4}</pre>
                    <button onclick="copyToClipboard('ss2022-hup-ntls')">Kopyala</button>
                </div>
                <div class="link-box">
                    <h3>gRPC</h3>
                    <pre id="ss2022-grpc">${ss22link5}</pre>
                    <button onclick="copyToClipboard('ss2022-grpc')">Kopyala</button>
                </div>
            </div>
        </div>
    </div>

    <div class="notification" id="notification">Kopyalandı!</div>

    <footer>
        <div class="footer-content">
            <div class="copyright">
                <p>Xray VPN Sayfası &copy; 2025 - Detaylı bilgi ve destek için onvao.net sitemizi ziyaret edebilirsiniz. T.me/onvaovpn telegram hesabından da ulaşabilirsiniz.</p>
            </div>
            <div class="app-buttons">
                <a href="https://play.google.com/store/apps/details?id=onvao.net.vpn" target="_blank" class="app-button">
                    <i class="fab fa-google-play"></i> Shadowsocks VPN İndir
                </a>
                <a href="https://play.google.com/store/apps/details?id=app.ikev2.vpn" target="_blank" class="app-button">
                    <i class="fab fa-google-play"></i> IKEv2 VPN İndir
                </a>
            </div>
        </div>
    </footer>

    <script>
        function copyToClipboard(elementId) {
            var codeElement = document.getElementById(elementId);
            var range = document.createRange();
            range.selectNodeContents(codeElement);
            var selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            try {
                document.execCommand('copy');
                showNotification();
            } catch (err) {
                console.error('Failed to copy text: ', err);
            }
        }

        function showNotification() {
            var notification = document.getElementById('notification');
            notification.style.display = 'block';
            setTimeout(function() {
                notification.style.display = 'none';
            }, 2000);
        }

        function toggleAccordion(element) {
            var content = element.nextElementSibling;
            if (content.classList.contains('show')) {
                content.classList.remove('show');
                content.style.maxHeight = null; // Reset max-height
            } else {
                var allContents = document.querySelectorAll('.accordion-content');
                allContents.forEach(function(c) {
                    c.classList.remove('show');
                    c.style.maxHeight = null; // Reset max-height for all other contents
                });
                content.classList.add('show');
                content.style.maxHeight = content.scrollHeight + 'px'; // Set max-height to scrollHeight
            }
        }
    </script>
</body>
</html>
END

# Restart Xray Service
systemctl restart xray

# Clear Screen
clear

# Kullanıcıya Bilgi Gösterme
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "              ----- [ Tüm Xray ] -----              " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "ISP            : $ISP" | tee -a /user/xray-$user.log
echo -e "Bölge          : $REG" | tee -a /user/xray-$user.log
echo -e "Şehir          : $CITY" | tee -a /user/xray-$user.log
echo -e "Port TLS/HTTPS : 443" | tee -a /user/xray-$user.log
echo -e "Port HTTP      : 80" | tee -a /user/xray-$user.log
echo -e "Transport      : XTLS-Vision, TCP TLS, Websocket, HTTPupgrade, gRPC" | tee -a /user/xray-$user.log
echo -e "Bitiş Tarihi   : $exp" | tee -a /user/xray-$user.log
echo -e "Link / Web     : https://$domain/xray/xray-$user.html" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "             ----- [ Vmess Bağlantısı ] -----             " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS TLS    : $vmesslink1" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS nTLS   : $vmesslink2" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP TLS   : $vmesslink3" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP nTLS  : $vmesslink4" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link gRPC      : $vmesslink5" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "             ----- [ Vless Bağlantısı ] -----             " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS TLS      : $vlesslink1" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS nTLS     : $vlesslink2" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP TLS     : $vlesslink3" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP nTLS    : $vlesslink4" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link gRPC        : $vlesslink5" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link XTLS-Vision : $vlesslink6" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "            ----- [ Trojan Bağlantısı ] -----             " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS TLS      : $trojanlink1" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS nTLS     : $trojanlink2" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP TLS     : $trojanlink3" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP nTLS    : $trojanlink4" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link gRPC        : $trojanlink5" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link TCP TLS     : $trojanlink6" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "          ----- [ Shadowsocks Bağlantısı ] -----          " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS TLS      : $sslink1" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS nTLS     : $sslink2" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP TLS     : $sslink3" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP nTLS    : $sslink4" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link gRPC        : $sslink5" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "       ----- [ Shadowsocks 2022 Bağlantısı ] -----        " | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS TLS      : $ss22link1" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link WS nTLS     : $ss22link2" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP TLS     : $ss22link3" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link HUP nTLS    : $ss22link4" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e "Link gRPC        : $ss22link5" | tee -a /user/xray-$user.log
echo -e "${BB}————————————————————————————————————————————————————${NC}" | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log
echo -e " " | tee -a /user/xray-$user.log

read -n 1 -s -r -p "Menüye dönmek için herhangi bir tuşa basın"
clear
allxray
