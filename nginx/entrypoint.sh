#!/bin/sh
set -e

mkdir -p /etc/nginx/certs

if [ ! -f /etc/nginx/certs/crm.crt ] || [ ! -f /etc/nginx/certs/crm.key ]; then
    echo "[CRM-Nginx] Chưa có chứng chỉ SSL, đang tạo chứng chỉ tự ký..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/certs/crm.key \
        -out /etc/nginx/certs/crm.crt \
        -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=CRM-CustomerCare/OU=IT/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:crm.local,IP:127.0.0.1" 2>/dev/null
    chmod 600 /etc/nginx/certs/crm.key
    chmod 644 /etc/nginx/certs/crm.crt
    echo "[CRM-Nginx] Đã tạo chứng chỉ tự ký thành công!"
fi

exec "$@"
