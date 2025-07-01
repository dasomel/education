#!/bin/bash

# WAS 서버의 내부 IP 주소를 환경 변수로 지정하세요.
WAS_IP="아이피"    # 실제 WAS VM의 내부 IP로 수정

# 1. Nginx 설치
sudo apt-get update
sudo apt-get install -y nginx

# 2. Nginx 기본 설정 백업
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak

# 3. Nginx 프록시 설정 (모든 요청을 WAS로 전달)
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://$WAS_IP:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 4. Nginx 재시작
sudo systemctl restart nginx

echo "Nginx가 $WAS_IP:8080으로 프록시하도록 설정되었습니다."
