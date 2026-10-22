#!/bin/bash
# ============================================================
# Script tạo chứng chỉ SSL/TLS tự ký cho CRM Chăm sóc Khách hàng
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

mkdir -p "${CERTS_DIR}"

CRT_FILE="${CERTS_DIR}/crm.crt"
KEY_FILE="${CERTS_DIR}/crm.key"

echo "Tạo chứng chỉ SSL/TLS tự ký cho CRM..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${KEY_FILE}" \
  -out "${CRT_FILE}" \
  -subj "/C=VN/ST=HoChiMinh/L=HoChiMinh/O=CRM-CustomerCare/OU=IT/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:crm.local,IP:127.0.0.1"

chmod 600 "${KEY_FILE}"
chmod 644 "${CRT_FILE}"

echo "Tạo chứng chỉ thành công tại: ${CERTS_DIR}"
echo "- Certificate: ${CRT_FILE}"
echo "- Private Key: ${KEY_FILE}"
