#!/usr/bin/env bash
# ============================================================
# Kich ban kiem thu toi uu - Bai thuc hanh 4
# Loki + Promtail + LogQL (Docker Compose)
#
# Chay tai thu muc goc du an tren Ubuntu:
#   bash KIEM_THU_BAI_THUC_HANH_4.sh
# Tuy chon:
#   SKIP_BUILD=1  -> khong rebuild image (nhanh hon)
#   BASE_URL=...   -> doi dia chi web (mac dinh http://localhost)
# ============================================================
set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
LOKI="${LOKI:-http://loki:3100}"
SKIP_BUILD="${SKIP_BUILD:-0}"

PASS=0; FAIL=0
pass() { printf '  \033[32m[PASS]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
head() { printf '\n\033[36m== %s ==\033[0m\n' "$*"; }

# Goi Loki tu trong container promtail (busybox wget co san tren Alpine)
loki_get() { docker compose exec -T promtail wget -qO- "$1" 2>/dev/null || true; }

# Kiem tra 1 LogQL (da ma hoa URL) co tra ve log khong; retry toi da ~20s
check_streams() { # $1=ten, $2=query da encode
  local name="$1" q="$2" out="" i
  for i in 1 2 3 4; do
    out="$(loki_get "${LOKI}/loki/api/v1/query_range?limit=20&query=${q}")"
    if printf '%s' "$out" | grep -q '"result":\[\]'; then sleep 5; continue; fi
    if printf '%s' "$out" | grep -q '"result":\['; then pass "$name - co log"; return 0; fi
    sleep 5
  done
  fail "$name - khong co log"
  return 1
}

head "TC-00: Kiem tra moi truong"
command -v docker >/dev/null 2>&1 && pass "docker co san" || { fail "thieu docker"; exit 1; }
docker compose version >/dev/null 2>&1 && pass "docker compose co san" || { fail "thieu docker compose"; exit 1; }
[ -f docker-compose.yml ] && pass "dung thu muc du an" || { fail "thieu docker-compose.yml"; exit 1; }
docker compose config --quiet >/dev/null 2>&1 && pass "docker-compose.yml hop le" || fail "docker-compose.yml loi cu phap"

head "TC-01: Khoi dong stack"
if [ "$SKIP_BUILD" = "1" ]; then docker compose up -d; else docker compose up -d --build; fi
for _ in $(seq 1 60); do
  n=$(docker compose ps --format '{{.Service}}' | wc -l | tr -d ' ')
  [ "$n" -ge 11 ] && break
  sleep 3
done
n=$(docker compose ps --format '{{.Service}}' | wc -l | tr -d ' ')
[ "$n" -ge 11 ] && pass "11/11 service dang chay" || fail "chi $n/11 service chay"
docker compose ps --format 'table {{.Service}}\t{{.Status}}'

app_health=$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q app)" 2>/dev/null || echo none)
case "$app_health" in
  healthy) pass "app healthy" ;;
  *)       fail "app health=$app_health" ;;
esac

head "TC-02: Loki san sang"
out=$(loki_get "${LOKI}/ready")
printf '%s' "$out" | grep -qx "ready" && pass "GET /ready -> ready" || fail "Loki /ready: ${out:-<empty>}"

head "TC-03: Promtail khong loi"
if docker compose logs promtail 2>&1 | grep -qiE 'level=error|panic|failed to'; then
  fail "Promtail co loi trong log"
  docker compose logs promtail --tail 20
else
  pass "Promtail log sach"
fi

head "TC-04: Sinh log (2 request phu het 3 query bat buoc)"
c=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/customers" \
  --data-urlencode "name=Kiem Thu KH $(date +%s)" --data-urlencode 'status=lead')
[ "$c" = "302" ] && pass "POST /customers -> 302 (customer_created)" || fail "POST /customers -> $c"

c=$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/khong-ton-tai")
[ "$c" = "404" ] && pass "GET /khong-ton-tai -> 404 (app ERROR + nginx 404)" || fail "GET /khong-ton-tai -> $c"

c=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/customers/1/interactions" \
  --data-urlencode 'type=call' --data-urlencode "subject=Kiem Thu $(date +%s)")
[ "$c" = "302" ] && pass "POST /customers/1/interactions -> 302 (interaction_created)" || fail "POST interaction -> $c"

head "TC-05: Cho Promtail day log"
sleep 12

head "TC-06..09: Truy van LogQL"
check_streams "Q1 customer_created" '%7Bservice%3D%22app%22%7D%20%7C%3D%20%22customer_created%22'
check_streams "Q2 ERROR"            '%7Bservice%3D%22app%22%7D%20%7C%3D%20%22ERROR%22'
check_streams "Q3 nginx 4xx/5xx"    '%7Bservice%3D%22nginx%22%7D%20%7C~%20%22%204%5B0-9%5D%7B2%7D%20%7C%205%5B0-9%5D%7B2%7D%20%22'
check_streams "Q4 interaction_created" '%7Bservice%3D%22app%22%7D%20%7C%3D%20%22interaction_created%22'

head "TC-10: Phan tach nhan service"
out=$(loki_get "${LOKI}/loki/api/v1/query_range?limit=5&query=%7Bservice%3D%22nginx%22%7D")
printf '%s' "$out" | grep -q '"service":"nginx"' && pass "stream co nhan service=nginx" || fail "khong thay nhan service=nginx"

head "TONG KET"
echo "PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m==> BAI THUC HANH 4: DAT ==\033[0m\n'
else
  printf '\033[31m==> BAI THUC HANH 4: CON %s MUC CHUA DAT ==\033[0m\n' "$FAIL"
  exit 1
fi
