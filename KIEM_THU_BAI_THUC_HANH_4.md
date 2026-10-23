# Kế hoạch kiểm thử — Bài thực hành 4: Loki + Promtail + LogQL

> **Mục tiêu:** Chứng minh hệ thống **thu thập log tập trung** hoạt động đúng: Promtail đọc log container → đẩy về Loki → truy vấn được bằng **LogQL** trên Grafana (tối thiểu 3 truy vấn bắt buộc).

---

## 1. Phạm vi & đối tượng kiểm thử

| Thành phần | File cấu hình liên quan |
|---|---|
| Loki (máy chủ lưu trữ log) | `logging/loki/loki-config.yml`, service `loki` trong `docker-compose.yml` |
| Promtail (bộ thu thập log) | `logging/promtail/promtail-config.yml`, service `promtail` |
| Nguồn log: app / nginx / db | `app/src/utils/logger.js`, `nginx/nginx.conf`, container `postgres` |
| Truy vấn LogQL | `logging/LOGQL_QUERIES.md` |

**Yêu cầu bắt buộc:** 3 truy vấn LogQL chạy được (xem mục 6).

---

## 2. Điều kiện tiên quyết

- Ubuntu Server 20.04/22.04, đã cài Docker Engine ≥ 24 và Docker Compose Plugin ≥ 2.20.
- Đứng tại thư mục gốc dự án (nơi có `docker-compose.yml`), đã có file `.env`.
- Cổng host trống: `80`, `443` (nginx), `3001` (Grafana), `9090` (Prometheus), `5050` (pgAdmin).
- **Lưu ý quan trọng:** `loki` và `promtail` **không publish port ra host**. Do đó để gọi trực tiếp Loki phải dùng `docker compose exec -T promtail wget ...` (xa hơn: `loki:3100` chỉ truy cập được trong mạng `monitoring`).

---

## 3. Kiểm thử tĩnh (làm trước khi chạy)

```bash
# 3.1 Hợp lệ cú pháp docker-compose (đồng thời kiểm tra .env đủ biến bắt buộc)
docker compose config --quiet && echo "compose OK"

# 3.2 Kiểm tra 2 file cấu hình logging tồn tại
ls -l logging/loki/loki-config.yml logging/promtail/promtail-config.yml

# 3.3 Promtail phải dùng label Compose để gán service (không phụ thuộc tên project)
grep -n "com_docker_compose_service" logging/promtail/promtail-config.yml
# Kỳ vọng: 2 dòng (rule keep + rule gán nhãn service)

# 3.4 Promtail phải có endpoint push đúng Loki
grep -n "loki:3100/loki/api/v1/push" logging/promtail/promtail-config.yml
```

**Kỳ vọng:** tất cả lệnh trả về 0 và in ra đúng nội dung.

---

## 4. Kịch bản kiểm thử tối ưu (End-to-End)

> **Vì sao tối ưu:** chỉ cần **2 request HTTP** là phủ đủ 3 truy vấn bắt buộc; hoàn toàn xác định (deterministic), không phá dữ liệu, chạy lại được nhiều lần, và tạo minh chứng ảnh chụp cho báo cáo.

### Bước 0 — Khởi động sạch

```bash
docker compose up -d --build
docker compose ps
# Kỳ vọng: 11 service đều ở trạng thái Up / healthy
```

### Bước 1 — Kiểm tra sức khoẻ pipeline

```bash
# Loki sẵn sàng (chạy từ trong container promtail trên mạng monitoring)
docker compose exec -T promtail wget -qO- http://loki:3100/ready
# Kỳ vọng: ready

# Promtail không có lỗi cấu hình
docker compose logs promtail | tail -20
# Kỳ vọng: không có dòng level=error / panic
```

### Bước 2 — Sinh log (2 request)

```bash
# (a) Tạo khách hàng → app ghi log INFO event="customer_created"
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost/customers \
  --data-urlencode "name=Kiem Thu Log $(date +%s)" \
  --data-urlencode "status=lead"
# Kỳ vọng: 302

# (b) Gọi URL không tồn tại → app ghi log ERROR event="unhandled_error"
#     đồng thời nginx ghi access log 404
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/khong-ton-tai
# Kỳ vọng: 404

# (c) [Tuỳ chọn] Tạo tương tác cho khách id=1 (có sẵn trong seed) → event="interaction_created"
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost/customers/1/interactions \
  --data-urlencode "type=call" \
  --data-urlencode "subject=Kiem thu $(date +%s)"
# Kỳ vọng: 302
```

### Bước 3 — Chờ Promtail thu thập & đẩy log

Chu kỳ quét của Promtail là 5 giây, batch gửi 1 giây → chờ **~12 giây** trước khi truy vấn:

```bash
sleep 12
```

### Bước 4 — Chạy 3 truy vấn LogQL (Grafana Explore)

1. Mở **http://127.0.0.1:3001** → đăng nhập bằng `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` trong `.env`.
2. Menu **☰ → Explore**.
3. Chọn Data source: **`Loki`**.
4. Đặt thời gian: **Last 15 minutes**.
5. Dán lần lượt các truy vấn dưới đây, bấm **Run query**.

| # | Truy vấn LogQL | Kỳ vọng |
|---|---|---|
| 1 | `{service="app"} \|= "customer_created"` | Thấy dòng JSON có `"event":"customer_created"` |
| 2 | `{service="app"} \|= "ERROR"` | Thấy dòng JSON có `"level":"ERROR","event":"unhandled_error"` |
| 3 | `{service="nginx"} \|~ " 4[0-9]{2} \| 5[0-9]{2} "` | Thấy access log nginx với status `404` |

> **Kiểm tra nâng cao (tuỳ chọn):** mở tab **Labels** trong Explore, chạy selector `{job="crm-docker"}` → danh sách label `service` chỉ có `app`, `nginx`, `db` (không lẫn `nginx-exporter`, `prometheus`, `grafana`…).

### Bước 5 — Truy vấn mở rộng (chứng minh thêm)

```logql
{service="app"} |= "interaction_created"
{service="db"}
rate({service="app"}[1m])
```

### Bước 6 — Thu thập minh chứng

Chụp màn hình cho báo cáo:
- `docker compose ps` (đủ 11 container Up).
- `docker compose exec -T promtail wget -qO- http://loki:3100/ready` → `ready`.
- Grafana Explore với **từng truy vấn 1, 2, 3** (có thời gian + kết quả log).

---

## 5. Bộ test case chi tiết

| ID | Tên | Tiền điều kiện | Bước thực hiện | Kỳ vọng |
|---|---|---|---|---|
| TC-00 | Môi trường hợp lệ | Có Docker | `docker compose config --quiet` | exit 0 |
| TC-01 | Stack khởi động | — | `docker compose up -d --build` rồi `docker compose ps` | 11 service Up, `app` healthy |
| TC-02 | Loki sẵn sàng | TC-01 | `docker compose exec -T promtail wget -qO- http://loki:3100/ready` | In ra `ready` |
| TC-03 | Promtail không lỗi | TC-01 | `docker compose logs promtail` | Không có `level=error`/`panic` |
| TC-04 | Ghi log nghiệp vụ | TC-01 | POST `/customers` | HTTP 302; Loki có `customer_created` |
| TC-05 | Ghi log lỗi app | TC-01 | GET `/khong-ton-tai` | HTTP 404; Loki có `unhandled_error` (ERROR) |
| TC-06 | Log access nginx | TC-01 | GET `/khong-ton-tai` (đã làm ở TC-05) | Loki có log nginx status 404 |
| TC-07 | Log tương tác (mở rộng) | TC-01 | POST `/customers/1/interactions` | Loki có `interaction_created` |
| TC-08 | Log db (mở rộng) | TC-01 | LogQL `{service="db"}` | Có log từ container PostgreSQL |
| TC-09 | Đếm log theo thời gian | TC-01 | LogQL `rate({service="app"}[1m])` | Trả về chuỗi số liệu (không rỗng) |
| TC-10 | Phân tách nhãn đúng | TC-01 | LogQL `{service="nginx"}` | Chỉ log nginx, nhãn `service="nginx"` |
| TC-11 | Không nhiễm log exporter | TC-01 | Label `{job="crm-docker"}` | `service` chỉ ∈ {app, nginx, db} |
| TC-12 | Chịu lỗi khi DB tạm mất | TC-01 | `docker compose stop db` rồi `curl /health` | `/health` → 503, log `health_check_failed` (ERROR); bật lại `db` sau test |

---

## 6. Tiêu chí nghiệm thu (Definition of Done)

Bài thực hành 4 **ĐẠT** khi:

- [ ] `loki` và `promtail` chạy, `Loki /ready` trả `ready`.
- [ ] Promtail không báo lỗi, thu thập được container `app`, `nginx`, `db`.
- [ ] Loki có stream với nhãn `service="app"`, `service="nginx"`, `service="db"`.
- [ ] **3/3 truy vấn bắt buộc** trả kết quả: `customer_created`, `ERROR`, nginx 4xx/5xx.
- [ ] Có ảnh chụp Grafana Explore cho 3 truy vấn + ảnh `docker compose ps`.
- [ ] Không lẫn log của exporter/cAdvisor/Grafana vào các nhãn `service`.

---

## 7. Xử lý sự cố nhanh

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Truy vấn `{service="app"}` rỗng | Promtail không nhận `service` label (sai regex/tên project) | Kiểm tra `logging/promtail/promtail-config.yml` dùng `com.docker.compose.service`; xem `/targets` |
| Loki nhận 0 log | Promtail không kết nối được Loki | `docker compose logs promtail`; kiểm tra `clients.url` = `http://loki:3100/loki/api/v1/push` |
| Query `level = "error"` rỗng | Log thực tế ghi `ERROR` (in hoa) | Dùng `level = "ERROR"` hoặc `\|= "ERROR"` |
| Không thấy log vừa sinh | Chưa hết chu kỳ quét/gửi | Chờ 10–15 giây rồi Run query lại; chỉnh time range "Last 15 minutes" |
| Explore không có datasource Loki | Provisioning sai path | Kiểm tra `monitoring/grafana/provisioning/datasources/` và `docker compose logs grafana` |
| Log bị nhân đôi sau restart | Promtail `positions` ở `/tmp` | Chấp nhận với demo; muốn chắc thì mount volume cho file positions |

---

## 8. Chạy tự động (khuyến nghị)

Toàn bộ kịch bản mục 4 đã được đóng gói thành script:

```bash
bash KIEM_THU_BAI_THUC_HANH_4.sh
# Nếu image đã build sẵn: SKIP_BUILD=1 bash KIEM_THU_BAI_THUC_HANH_4.sh
```

Script sẽ tự: kiểm tra môi trường → khởi động stack → kiểm tra Loki/Promtail → sinh log → chờ → chạy 4 truy vấn qua Loki API → in bảng `PASS/FAIL` và **exit 1 nếu có mục chưa đạt**.

> Script chỉ đọc/ghi dữ liệu demo (tạo 1 khách hàng, 1 tương tác); chạy lại nhiều lần vẫn an toàn.
