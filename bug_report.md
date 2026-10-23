# Báo cáo Bug Review — Dự án CRM (Task 3)

## 🔴 BUG NGHIÊM TRỌNG (sẽ crash hoặc silent data corruption)

### BUG 1 — `updated_at` KHÔNG được cập nhật khi UPDATE
**File:** `app/src/services/customerService.js` — hàm `update()` (dòng 79–87)

```sql
-- Câu lệnh SQL hiện tại:
UPDATE customers
SET name=$1, company_name=$2, industry=$3, email=$4, phone=$5, address=$6, status=$7
WHERE id=$8 AND deleted_at IS NULL RETURNING *
```
`updated_at` không được cập nhật trong câu UPDATE → view `show.ejs` hiển thị ngày cập nhật sai.

**Sửa:** Thêm `updated_at = NOW()` vào SET.

---

### BUG 2 — Grafana Dashboard: metric name không khớp với code
**File:** `monitoring/grafana/dashboards/crm-overview.json` — nhiều panel

Code trong `metrics.js` đăng ký metrics với prefix **`crm_`**:
- `crm_http_requests_total` (label: `status_code`)
- `crm_http_request_duration_seconds`
- `crm_customers_created_total`
- `crm_interactions_created_total`
- `crm_process_resident_memory_bytes` (default metric với prefix `crm_`)
- `crm_nodejs_heap_size_used_bytes`

Nhưng dashboard có các panel dùng tên sai (đã bị đổi qua rebase conflict):

| Panel | PromQL trong dashboard | Tên metric thực tế | Lỗi |
|-------|----------------------|---------------------|-----|
| HTTP Requests rate | `sum by (status) (rate(http_requests_total[1m]))` | `crm_http_requests_total` label `status_code` | Sai tên + sai label |
| Error rate 5xx | `rate(http_requests_total{status=~"5.."}[5m])` | `crm_http_requests_total{status_code=~"5.."}` | Sai tên + sai label |
| Latency p50/p95/p99 | `crm_http_request_duration_seconds_bucket` | `crm_http_request_duration_seconds_bucket` | ✅ OK |
| Memory RSS | `process_resident_memory_bytes{service="app"}` | `crm_process_resident_memory_bytes` | Sai tên |
| Memory Heap | `nodejs_heap_size_used_bytes{service="app"}` | `crm_nodejs_heap_size_used_bytes` | Sai tên |
| Business counters | `crm_customers_total` | `crm_customers_created_total` | Sai tên |
| Business counters | `crm_interactions_total` | `crm_interactions_created_total` | Sai tên |

**Nguyên nhân:** Khi giải quyết rebase conflict, dashboard bị revert về version cũ (từ origin/main) với tên metrics sai.

---

### BUG 3 — Grafana Dashboard Provisioning: path sai
**File:** `monitoring/grafana/provisioning/dashboards/dashboards.yml`

```yaml
options:
  path: /etc/grafana/dashboards     # ← đang dùng path này
```

**Docker Compose** mount dashboard vào:
```yaml
- ./monitoring/grafana/dashboards:/etc/grafana/dashboards:ro  # ✅ Khớp
```
Path `/etc/grafana/dashboards` hiện tại là ĐÚNG — không có bug ở đây.

---

### BUG 4 — XSS: EJS render dữ liệu người dùng không escape
**Files:** `show.ejs`, `dashboard.ejs`, `index.ejs`

Dùng `<%= %>` (escaped) cho text content → ✅ An toàn.
Không dùng `<%- %>` cho user data → ✅ OK.

---

### BUG 5 — `nginx-exporter` scrapes `nginx:8080/stub_status` nhưng nginx chỉ cho phép IP nội bộ
**File:** `nginx/nginx.conf` — server 8080 (dòng 132–136)

```nginx
allow 127.0.0.1;
allow 10.0.0.0/8;
allow 172.16.0.0/12;
allow 192.168.0.0/16;
deny all;
```

Docker network thường dùng dải `172.16.0.0/12` → ✅ nginx-exporter có thể truy cập được.

---

## 🟡 BUG TRUNG BÌNH (logic lỗi nhưng không crash)

### BUG 6 — `contactService.create()`: Race condition với `is_primary`
**File:** `app/src/services/contactService.js` (dòng 26–30)

```javascript
if (is_primary) {
  await pool.query('UPDATE contacts SET is_primary = FALSE WHERE customer_id = $1', [customer_id]);
}
// Rồi mới INSERT...
```

Hai requests đồng thời có thể tạo 2 primary contacts. Không dùng transaction → không đảm bảo atomicity. Tuy nhiên có `UNIQUE INDEX contacts_one_primary_per_customer` sẽ block ở DB level, gây lỗi 500 thay vì 422.

---

### BUG 7 — `contactRoutes.js`: Khi validation fail, render form với `customer = null` nếu getById trả về null
**File:** `app/src/routes/contactRoutes.js` (dòng 22–30)

```javascript
const customer = await customerService.getById(req.params.customerId);
return res.status(422).render('contacts/form', {
  title: 'Thêm liên hệ',
  customer,  // ← có thể null nếu customer đã bị xóa
  ...
});
```

Nếu customer bị xóa mềm trong khi form đang mở, `customer` sẽ là `null` → `contacts/form.ejs` dùng `customer.id`, `customer.name` → **crash 500** (TypeError).

---

### BUG 8 — `interactionService.create()`: `occurred_at` nhận chuỗi string từ form
**File:** `app/src/services/interactionService.js` (dòng 49)

```javascript
[customer_id, contact_id || null, type, subject, notes || null, occurred_at || new Date()]
```

`occurred_at` từ HTML form là string `"2024-01-15T10:30"` (datetime-local format, không có timezone). PostgreSQL sẽ nhận nhưng có thể interpret sai timezone. Nên parse hoặc để PostgreSQL xử lý.

---

### BUG 9 — `customerService.update()`: Không validate `status` ở service layer
Chỉ validate ở route với express-validator, nhưng service `update()` nhận `status` từ `data` object trực tiếp mà không kiểm tra. Nếu ai gọi service trực tiếp hoặc bypass route validation, có thể vi phạm CHECK constraint của DB → lỗi 500.

---

## 🟠 BUG CẤU HÌNH (sẽ ảnh hưởng khi deploy)

### BUG 10 — Promtail: Regex filter chỉ giữ container tên `crm-*`
**File:** `logging/promtail/promtail-config.yml` (dòng 26–28)

```yaml
- source_labels: ['__meta_docker_container_name']
  regex: '/?(crm-[a-zA-Z0-9_-]+)'
  action: keep
```

Containers như `cadvisor`, `loki`, `promtail` bản thân sẽ không được thu thập log nếu tên không có prefix `crm-`. Đây là hành vi có chủ đích, không phải bug.

---

### BUG 11 — `postgres-exporter` dùng `crm_app` user để connect nhưng user này không có quyền SELECT system catalogs
Một số metrics của postgres-exporter cần quyền `pg_monitor` hoặc superuser để đọc `pg_stat_statements`, `pg_stat_bgwriter`... `crm_app` chỉ có SELECT trên app tables → một số metrics sẽ không thu thập được.

---

## ✅ CÁC ĐIỂM TỐT (không có bug)

| Hạng mục | Trạng thái |
|----------|-----------|
| SQL injection prevention | ✅ Parameterized queries 100% |
| Soft delete logic | ✅ Đúng |
| DB pool configuration | ✅ max=20, timeout hợp lý |
| Docker health checks | ✅ Đầy đủ |
| Security headers (nginx) | ✅ Đầy đủ |
| HSTS chỉ trên HTTPS | ✅ Đúng |
| DB init order (10→20→30→40) | ✅ Đúng |
| Error handler không lộ stack | ✅ Đúng |
| Secrets không trong .env.example | ✅ Đúng |
| .gitignore | ✅ Đầy đủ |
| prom-client prefix `crm_` | ✅ Nhất quán |

---

## 📋 TÓM TẮT CẦN SỬA

| # | Mức độ | File | Vấn đề | Cần sửa |
|---|--------|------|---------|---------|
| 1 | 🔴 | `customerService.js` | `updated_at` không cập nhật khi UPDATE | Thêm `updated_at=NOW()` |
| 2 | 🔴 | `crm-overview.json` | Metric names sai do rebase conflict | Fix PromQL về `crm_*` + `status_code` |
| 6 | 🟡 | `contactService.js` | Race condition is_primary không atomic | Dùng transaction |
| 7 | 🟡 | `contactRoutes.js` | customer=null crash khi render form error | Thêm null check |
| 8 | 🟡 | `interactionService.js` | occurred_at timezone ambiguous | Parse datetime |
| 11 | 🟠 | `docker-compose.yml` | postgres-exporter thiếu quyền pg_monitor | Grant quyền cho crm_app |
