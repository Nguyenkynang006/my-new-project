# Hệ thống CRM Chăm sóc Khách hàng (Customer Care CRM)

Đồ án thực hành môn **Triển khai và Quản trị Hệ thống Phần mềm**.

Hệ thống ứng dụng web CRM quản lý khách hàng, người liên hệ và lịch sử tương tác; triển khai đóng gói hoàn chỉnh bằng **Docker Compose** trên nền tảng Ubuntu Server với kiến trúc Microservices bao gồm: **Node.js Express + PostgreSQL + pgAdmin + Nginx Reverse Proxy (SSL/TLS & Security Headers) + Prometheus + Grafana Dashboard + Loki + Promtail**.

---

## 📑 Mục lục
1. [Giới thiệu bài toán và Chức năng](#1-giới-thiệu-bài-toán-và-chức-năng)
2. [Kiến trúc Hệ thống](#2-kiến-trúc-hệ-thống)
3. [Danh sách Dịch vụ và Cổng mạng](#3-danh-sách-dịch-vụ-và-cổng-mạng)
4. [Yêu cầu Môi trường](#4-yêu-cầu-môi-trường)
5. [Hướng dẫn Cài đặt và Khởi chạy](#5-hướng-dẫn-cài-đặt-và-khởi-chạy)
6. [Địa chỉ Truy cập và Tài khoản Demo](#6-địa-chỉ-truy-cập-và-tài-khoản-demo)
7. [Hướng dẫn Nghiệm thu và Kiểm thử](#7-hướng-dẫn-nghiệm-thu-và-kiểm-thử)
   - [7.1. Chức năng CRM & Cơ sở dữ liệu](#71-chức-năng-crm--cơ-sở-dữ-liệu)
   - [7.2. Nginx Reverse Proxy, SSL/TLS & Security Headers](#72-nginx-reverse-proxy-ssltls--security-headers)
   - [7.3. Giám sát Prometheus & Grafana](#73-giám-sát-prometheus--grafana)
   - [7.4. Quản lý Log tập trung với Loki, Promtail & LogQL](#74-quản-lý-log-tập-trung-với-loki-promtail--logql)
8. [Các biện pháp Bảo mật và Hardening Hệ thống](#8-các-biện-pháp-bảo-mật-và-hardening-hệ-thống)
9. [Lịch sử Commit Kỹ thuật (Milestones)](#9-lịch-sử-commit-kỹ-thuật-milestones)
10. [Khắc phục Sự cố Thường gặp](#10-khắc-phục-sự-cố-thường-gặp)

---

## 1. Giới thiệu bài toán và Chức năng

Hệ thống giải quyết bài toán quản trị quan hệ khách hàng cho doanh nghiệp với các chức năng trọng tâm:

- **Quản lý Khách hàng (Customer Management):**
  - Xem danh sách khách hàng kèm phân trang, tìm kiếm đa tiêu chí (tên, công ty, email, số điện thoại) và bộ lọc theo trạng thái (`lead`, `active`, `inactive`).
  - Thêm mới, chỉnh sửa thông tin khách hàng với form xác thực chặt chẽ (`express-validator`).
  - Xóa khách hàng với xác nhận an toàn (bảo toàn ràng buộc khóa ngoại `RESTRICT`).
- **Quản lý Người liên hệ (Contact Management):**
  - Mỗi khách hàng có thể có nhiều người liên hệ đại diện (họ tên, chức vụ, email, điện thoại, ghi chú).
  - Đánh dấu người liên hệ chính (`is_primary`).
  - Thêm, sửa, xóa người liên hệ ngay trên giao diện chi tiết khách hàng.
- **Quản lý Lịch sử Tương tác (Interaction Tracking):**
  - Ghi nhận lịch sử chăm sóc: Cuộc gọi (`call`), Email (`email`), Cuộc họp (`meeting`), Ghi chú (`note`).
  - Gắn tương tác với một người liên hệ cụ thể hoặc toàn công ty.
  - Hiển thị dòng thời gian tương tác (Interactive Timeline) theo thứ tự mới nhất trước.
- **Thống kê & Dashboard:**
  - Tổng số khách hàng, phân loại theo trạng thái kinh doanh, các tương tác gần nhất.

---

## 2. Kiến trúc Hệ thống

```
                                  ┌───────────────────────────┐
                                  │   Trình duyệt Người dùng  │
                                  └─────────────┬─────────────┘
                                                │ HTTP:80 / HTTPS:443
                                  ┌─────────────▼─────────────┐
                                  │   Nginx Reverse Proxy     │
                                  │ (SSL/TLS + Sec Headers)   │
                                  └─────────────┬─────────────┘
                                                │ proxy_pass:3000
                       ┌────────────────────────▼────────────────────────┐
                       │           Node.js Express App                   │
                       │   (CRUD CRM, /health, /metrics, JSON Logger)    │
                       └────────┬───────────────────────┬────────────────┘
                                │ :5432                 │ /metrics
           ┌────────────────────▼─────┐           ┌─────▼──────────┐
           │   PostgreSQL 16 Alpine   │           │   Prometheus   │◄── cAdvisor (Containers)
           │ (crm_db, persistent vol) │           │    v2.51.0     │◄── postgres-exporter (:9187)
           └──────────────────────────┘           └────────┬───────┘◄── nginx-exporter (:9113)
                        ▲                                  │
                        │ kết nối nội bộ                   ▼
           ┌────────────┴─────────────┐           ┌────────────────┐
           │      pgAdmin 4 (:5050)   │           │    Grafana     │
           │ (Quản trị Web Database)  │           │    v10.4.0     │
           └──────────────────────────┘           │ (Bảng điều     │
                                                  │  khiển giám    │
     ┌──────────────┐     Docker Socket           │  sát & Log)    │
     │   Promtail   │──────────────────────► Loki │                │
     │    v2.9.6    │   (Thu thập stdout)   v2.9.6└────────▲───────┘
     └──────────────┘                                      │
            │                                              │
            └────────── Đẩy log qua HTTP API ──────────────┘
```

Hệ thống phân tách mạng nội bộ thành 3 Docker Networks độc lập:
1. `edge`: Mạng tiếp nhận traffic bên ngoài vào Nginx và chuyển tiếp tới App.
2. `data`: Mạng dữ liệu cách ly tuyệt đối, chứa PostgreSQL, pgAdmin và postgres-exporter. Cơ sở dữ liệu **không publish cổng ra host**.
3. `monitoring`: Mạng thu thập dữ liệu giám sát giữa Prometheus, Grafana, Loki, Promtail, cAdvisor và các Exporter.

---

## 3. Danh sách Dịch vụ và Cổng mạng

| Service Name | Container Name | Image / Build | Vai trò | Cổng Host | Mạng Docker |
|---|---|---|---|---|---|
| `nginx` | `crm-nginx` | `./nginx` (Alpine) | Cổng vào Reverse Proxy, SSL, Security Headers | `80`, `443` | `edge`, `monitoring` |
| `app` | `crm-app` | `./app` (Node:20-Alpine) | Ứng dụng CRM Web + API | Không expose host | `edge`, `data` |
| `db` | `crm-db` | `postgres:16-alpine` | Cơ sở dữ liệu quan hệ chính | Không expose host | `data` |
| `pgadmin` | `crm-pgadmin` | `dpage/pgadmin4` | Giao diện quản trị PostgreSQL | `5050` | `data` |
| `prometheus` | `crm-prometheus` | `prom/prometheus:v2.51.0` | Máy chủ thu thập Metrics | `9090` | `monitoring`, `edge`, `data` |
| `grafana` | `crm-grafana` | `grafana/grafana:10.4.0` | Bảng điều khiển trực quan hóa Metrics & Log | `3001` | `monitoring` |
| `postgres-exporter` | `crm-postgres-exporter` | `prometheuscommunity/postgres-exporter` | Exporter trích xuất metrics PostgreSQL | Không expose host | `data`, `monitoring` |
| `nginx-exporter` | `crm-nginx-exporter` | `nginx/nginx-prometheus-exporter` | Exporter đọc Nginx `stub_status` | Không expose host | `edge`, `monitoring` |
| `cadvisor` | `crm-cadvisor` | `gcr.io/cadvisor/cadvisor` | Giám sát CPU, RAM, Network container | Không expose host | `monitoring` |
| `loki` | `crm-loki` | `grafana/loki:2.9.6` | Máy chủ lưu trữ và xử lý Log tập trung | Không expose host | `monitoring` |
| `promtail` | `crm-promtail` | `grafana/promtail:2.9.6` | Thu thập log container từ Docker Socket | Không expose host | `monitoring` |

---

## 4. Yêu cầu Môi trường

- **Hệ điều hành:** Ubuntu Server 20.04 / 22.04 LTS (hoặc Ubuntu Desktop / Windows WSL2)
- **Công cụ bắt buộc:**
  - Docker Engine `>= 24.0.0`
  - Docker Compose Plugin `>= 2.20.0`
  - Git `>= 2.30.0`
- **Tài nguyên tối thiểu khuyến nghị:** 2 vCPU, 4GB RAM, 10GB dung lượng đĩa trống.

---

## 5. Hướng dẫn Cài đặt và Khởi chạy

### Bước 1: Clone repository
```bash
git clone <URL_REPOSITORY_CUA_BAN>
cd crm-customer-care
```

### Bước 2: Thiết lập biến môi trường
Sao chép file mẫu `.env.example` thành `.env` và cấu hình mật khẩu an toàn:
```bash
cp .env.example .env
```
Chỉnh sửa mật khẩu trong `.env` bằng trình soạn thảo (`nano` hoặc `vim`):
```bash
nano .env
```
> **Lưu ý bảo mật:** File `.env` chứa mật khẩu thật và đã được đưa vào `.gitignore`. Tuyệt đối không commit file `.env` lên GitHub.

### Bước 3: Khởi chạy toàn bộ hệ thống bằng Docker Compose
```bash
docker compose up -d --build
```

### Bước 4: Kiểm tra trạng thái hoạt động của các container
```bash
docker compose ps
```
Tất cả 11 container cần ở trạng thái `running` (hoặc `healthy`).

Kiểm tra log khởi động nếu cần:
```bash
docker compose logs -f --tail=100
```

### Dừng hệ thống:
```bash
# Dừng các container (dữ liệu database và volume vẫn được bảo toàn)
docker compose down

# Xóa toàn bộ volume nếu muốn reset trắng dữ liệu
docker compose down -v
```

---

## 6. Địa chỉ Truy cập và Tài khoản Demo

| Dịch vụ | URL Truy cập | Tài khoản / Mật khẩu |
|---|---|---|
| **Website CRM (HTTP)** | `http://localhost/` hoặc `http://<IP_UBUNTU>/` | Không yêu cầu đăng nhập |
| **Website CRM (HTTPS)** | `https://localhost/` hoặc `https://<IP_UBUNTU>/` | Chấp nhận cảnh báo chứng chỉ tự ký |
| **pgAdmin 4** | `http://localhost:5050/` | Email: `admin@example.test`<br>Mật khẩu: *(Xem trong `.env`)* |
| **Grafana Dashboard** | `http://localhost:3001/` | User: `admin`<br>Mật khẩu: *(Xem `GRAFANA_ADMIN_PASSWORD` trong `.env`)* |
| **Prometheus Web UI** | `http://localhost:9090/` | Không yêu cầu |
| **Loki API / Readiness**| `http://localhost:3100/ready` | Trả về `ready` |

---

## 7. Hướng dẫn Nghiệm thu và Kiểm thử

### 7.1. Chức năng CRM & Cơ sở dữ liệu

1. **Kiểm tra Website CRM qua Nginx:**
   - Mở trình duyệt tại `http://localhost/`. Trang Dashboard hiển thị các thẻ thống kê tổng số khách hàng và lịch sử chăm sóc gần nhất.
   - Nhấn **"Danh sách khách hàng"**: Xem danh sách dữ liệu mẫu đã được nạp tự động (`database/sample-data.sql`).
   - Thử nghiệm tìm kiếm: Nhập từ khóa tên công ty, số điện thoại hoặc chọn bộ lọc trạng thái.
2. **Thực hiện luồng CRUD:**
   - **Tạo khách hàng mới:** Nhấn "Thêm khách hàng", nhập thông tin hợp lệ và lưu.
   - **Thêm người liên hệ:** Mở chi tiết khách hàng vừa tạo, nhấn "Thêm người liên hệ", chọn người liên hệ chính.
   - **Ghi nhật ký tương tác:** Nhấn "Ghi tương tác mới", chọn hình thức (Cuộc gọi/Email/Gặp mặt), nhập tiêu đề và nội dung.
   - Làm mới trang chi tiết: Dòng thời gian tương tác cập nhật chính xác.
3. **Kiểm tra dữ liệu trên pgAdmin:**
   - Đăng nhập `http://localhost:5050` với tài khoản pgAdmin.
   - Nhấn **Add New Server**:
     - General tab: Name = `CRM Database`
     - Connection tab: Host = `db`, Port = `5432`, Database = `crm_db`, Username = `crm_app`, Password = *(mật khẩu trong `.env`)*.
   - Truy vấn bảng: Mở `crm_db` → `Schemas` → `public` → `Tables`. Xem dữ liệu bảng `customers`, `contacts`, `interactions` để xác nhận dữ liệu đã được lưu trữ bền vững.
4. **Kiểm tra Volume lưu trữ bền vững (Persistence):**
   ```bash
   docker compose restart db app
   ```
   Tải lại trang web: Mọi thông tin khách hàng vừa tạo vẫn còn nguyên vẹn.

---

### 7.2. Nginx Reverse Proxy, SSL/TLS & Security Headers

1. **Kiểm tra Security Headers:**
   Chạy lệnh `curl` để kiểm tra response headers từ Nginx:
   ```bash
   curl -I http://localhost/
   ```
   Kết quả trả về các header bảo mật bắt buộc:
   - `X-Frame-Options: SAMEORIGIN` (Chống Clickjacking)
   - `X-Content-Type-Options: nosniff` (Chống MIME-type sniffing)
   - `X-XSS-Protection: 1; mode=block` (Chống Cross-site scripting)
   - `Referrer-Policy: strict-origin-when-cross-origin`
   - `Content-Security-Policy: ...` (Kiểm soát nguồn tải tài nguyên an toàn)
   - Không có header để lộ phiên bản Nginx (`server_tokens off`).
2. **Kiểm tra HTTPS tự ký:**
   Truy cập `https://localhost/` hoặc chạy lệnh:
   ```bash
   curl -kI https://localhost/
   ```
   Kết quả xác nhận kết nối qua cổng 443 với giao thức TLSv1.2/TLSv1.3 và có header `Strict-Transport-Security` (HSTS).

---

### 7.3. Giám sát Prometheus & Grafana

1. **Kiểm tra Prometheus Targets:**
   - Mở `http://localhost:9090/targets`.
   - Xác nhận tất cả 4 targets đều ở trạng thái **`UP (1/1)`**:
     - `crm-app` (`app:3000/metrics`)
     - `nginx` (`nginx-exporter:9113`)
     - `postgres` (`postgres-exporter:9187`)
     - `cadvisor` (`cadvisor:8080`)
2. **Trải nghiệm Grafana Dashboard:**
   - Mở `http://localhost:3001` và đăng nhập.
   - Vào menu **Dashboards** → chọn thư mục **"CRM System"** → mở dashboard **"CRM System Overview — Giám sát Toàn diện"**.
   - Bảng điều khiển đã được cấu hình tự động (Provisioning) với đầy đủ các bảng chỉ số:
     - Thẻ KPI: Tổng số HTTP requests, Tỉ lệ lỗi 5xx, Số kết nối Nginx, Số truy vấn Active PostgreSQL.
     - Biểu đồ HTTP request rate theo status code và độ trễ phản hồi (p50, p95, p99).
     - Biểu đồ bộ nhớ RSS/Heap của Node.js.
     - Biểu đồ tần suất transaction commit/rollback của PostgreSQL.
     - Biểu đồ mức sử dụng CPU & RAM chi tiết của từng container từ cAdvisor.

---

### 7.4. Quản lý Log tập trung với Loki, Promtail & LogQL

1. **Truy cập Grafana Explore:**
   - Trong Grafana, vào menu **Explore** (biểu tượng la bàn).
   - Chọn Data source: **`Loki`**.
2. **Chạy 3 truy vấn LogQL bắt buộc theo đề cương môn học:**

   - **Truy vấn 1 — Tìm sự kiện tạo khách hàng (`customer_created`):**
     ```logql
     {service="app"} |= "customer_created"
     ```
     *(Hoặc dạng JSON trích xuất trường: `{service="app"} | json | event="customer_created"`)*

   - **Truy vấn 2 — Tìm thông báo lỗi trong ứng dụng (`ERROR`):**
     ```logql
     {service="app"} |= "ERROR"
     ```

   - **Truy vấn 3 — Lọc request HTTP có mã lỗi 4xx hoặc 5xx từ Nginx:**
     ```logql
     {service="nginx"} |~ " 4[0-9]{2} | 5[0-9]{2} "
     ```

Chi tiết tài liệu và các truy vấn LogQL mở rộng xem thêm tại file [`logging/LOGQL_QUERIES.md`](file:///c:/CRM/logging/LOGQL_QUERIES.md).

---

## 8. Các biện pháp Bảo mật và Hardening Hệ thống

Hệ thống đã triển khai đầy đủ các biện pháp Hardening toàn diện theo yêu cầu đề tài:

1. **Non-Root Container:** Container ứng dụng Express chạy dưới tài khoản `appuser` (UID: 1001, GID: 1001), không sử dụng quyền root trong runtime.
2. **Network Isolation (Phân tách mạng):**
   - Cơ sở dữ liệu PostgreSQL chỉ nằm trong mạng nội bộ `data`, **không publish bất kỳ port nào ra ngoài Internet**.
   - Ứng dụng CRM chỉ giao tiếp qua mạng `edge` với Nginx và mạng `data` với PostgreSQL.
3. **Quản lý Secrets & Biến môi trường An toàn:**
   - Không commit file `.env`, mật khẩu thật hay private key lên Git (quy định chặt chẽ trong `.gitignore`).
   - Sử dụng `.env.example` với giá trị placeholder.
4. **Security Headers & SSL Hardening tại Nginx:**
   - Ẩn thông tin phiên bản Nginx (`server_tokens off`).
   - Bổ sung đầy đủ CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, HSTS.
   - Hạn chế quyền truy cập endpoint nội bộ `/stub_status` chỉ cho subnet Docker nội bộ.
5. **Phòng chống tấn công ứng dụng Web:**
   - Dùng Parameterized Queries với PostgreSQL (`pg`) ngăn ngừa triệt để lỗ hổng SQL Injection.
   - Xác thực và chuẩn hóa dữ liệu đầu vào bằng `express-validator`.
   - Error handler che giấu chi tiết stack trace với người dùng cuối, chỉ ghi cấu trúc log ra máy chủ.

---

## 9. Lịch sử Commit Kỹ thuật (Milestones)

Lịch sử Git tuân thủ nghiêm ngặt 3 mốc kỹ thuật độc lập phục vụ đánh giá rubric:

1. **Nền tảng Ứng dụng & Database:**
   - Commit: `feat: implement CRM web application and PostgreSQL database schema`
2. **Commit Mốc 1 (Nginx Reverse Proxy & Security Headers):**
   - Commit: `feat: configure nginx reverse proxy and security headers`
3. **Commit Mốc 2 (Prometheus & Grafana Giám sát):**
   - Commit: `feat: add prometheus grafana and service monitoring`
4. **Commit Mốc 3 (Loki & Promtail Quản lý Log tập trung):**
   - Commit: `feat: add centralized logging with loki and promtail`

---

## 10. Khắc phục Sự cố Thường gặp

| Vấn đề | Nguyên nhân | Cách xử lý |
|---|---|---|
| Port 80 hoặc 5050 đã bị chiếm | Tiến trình khác (Apache, IIS) đang lắng nghe trên cổng này | Đổi cổng host trong `docker-compose.yml` (ví dụ `8080:80`) hoặc dừng tiến trình chiếm dụng. |
| crm-app báo lỗi kết nối DB | Database đang trong giai đoạn khởi tạo lần đầu | Container `app` đã có `depends_on: db: condition: service_healthy` tự động đợi PostgreSQL sẵn sàng. |
| Targets Prometheus báo DOWN | Service chưa kịp khởi động hoặc sai network | Chạy `docker compose ps` kiểm tra container tương ứng và kiểm tra log bằng `docker compose logs <tên_service>`. |
| Loki không nhận log từ Promtail | Đường dẫn Docker socket chưa đúng quyền trên Ubuntu | Trên Ubuntu, đảm bảo user chạy Docker nằm trong nhóm `docker` hoặc Promtail mount đúng `/var/run/docker.sock`. |
