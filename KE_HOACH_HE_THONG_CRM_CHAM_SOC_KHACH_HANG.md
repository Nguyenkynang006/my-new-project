# Kế hoạch xây dựng Hệ thống CRM Chăm sóc Khách hàng

> **Mục tiêu:** Xây dựng ứng dụng web CRM để quản lý khách hàng, người liên hệ và lịch sử tương tác; triển khai toàn bộ bằng Docker Compose với PostgreSQL + pgAdmin, Nginx reverse proxy, Prometheus + Grafana và Loki + Promtail. Quản lý mã nguồn và cấu hình trên GitHub, có README hướng dẫn khởi chạy và minh chứng cho các tiêu chí đánh giá.

## 1. Phạm vi hệ thống

### 1.1. Chức năng người dùng

- Xem danh sách và thông tin chi tiết khách hàng.
- Tạo, sửa, xóa và tìm kiếm khách hàng theo tên/công ty, email, số điện thoại hoặc trạng thái.
- Quản lý một hoặc nhiều người liên hệ thuộc mỗi khách hàng: họ tên, chức vụ, email, số điện thoại và liên hệ chính.
- Ghi nhận lịch sử tương tác với khách hàng hoặc một người liên hệ: cuộc gọi, email, cuộc họp, ghi chú; gồm tiêu đề, nội dung và thời điểm.
- Xem lịch sử tương tác theo khách hàng, sắp xếp mới nhất trước.
- Lọc khách hàng theo trạng thái, ví dụ: tiềm năng, đang chăm sóc, khách hàng hiện tại, ngừng hoạt động.

### 1.2. Chức năng quản trị cơ bản

- Quản lý khách hàng, liên hệ và tương tác bằng các thao tác CRUD.
- Xem số lượng khách hàng theo trạng thái và các tương tác gần đây.
- Nếu còn thời gian, thêm đăng nhập quản trị viên và phân quyền đơn giản; phần này là mở rộng, không thay thế các chức năng CRM chính.

### 1.3. Phi chức năng

- Khởi chạy toàn bộ ứng dụng và công cụ đi kèm bằng Docker Compose.
- Dữ liệu được lưu trong PostgreSQL, có volume bền vững và được kiểm tra bằng pgAdmin.
- Nginx là cổng truy cập website; hỗ trợ HTTPS tự ký hoặc tối thiểu security headers cơ bản.
- Prometheus thu thập metrics ứng dụng, web server, database và container; Grafana trình bày dashboard.
- Loki + Promtail tập trung log và cho phép truy vấn ít nhất 2–3 câu LogQL.
- Áp dụng ít nhất 3–4 biện pháp hardening: non-root container, network isolation, mật khẩu mạnh, hạn chế quyền DB, security headers, không lộ secret.
- Không commit mật khẩu, secret, private key hoặc file `.env` thật lên GitHub.

## 2. Công nghệ sử dụng

| Thành phần | Công nghệ đề xuất | Vai trò |
|---|---|---|
| Web application | Node.js + Express | Giao diện/API CRM và endpoint health/metrics |
| Cơ sở dữ liệu | PostgreSQL | Lưu khách hàng, liên hệ và lịch sử tương tác |
| Quản trị CSDL | pgAdmin | Xem, kiểm tra và quản trị PostgreSQL |
| Reverse proxy | Nginx | Cổng truy cập website, proxy và security headers/HTTPS |
| Đóng gói/triển khai | Docker + Docker Compose | Chạy toàn bộ dịch vụ nhất quán |
| Metrics ứng dụng | prom-client | Expose endpoint `/metrics` cho Express |
| Metrics tập trung | Prometheus | Thu thập metrics từ các target |
| Dashboard | Grafana | Hiển thị metrics và truy vấn log |
| Metrics container | cAdvisor | CPU, RAM, network và filesystem của container |
| Metrics PostgreSQL | postgres-exporter | Connections, transactions, uptime và trạng thái PostgreSQL |
| Metrics Nginx | nginx-prometheus-exporter | Metrics từ Nginx `stub_status` |
| Logging tập trung | Loki + Promtail | Thu thập, lưu và truy vấn log container |
| Quản lý mã nguồn | GitHub | Repository, lịch sử commit và README |

Có thể dùng Python (Flask/Django) thay Express nếu đã quen hơn; cần giữ nguyên các thành phần hạ tầng và đầu ra metrics/logging.

## 3. Kiến trúc tổng quan

```text
                         ┌──────────────────┐
                         │    Người dùng     │
                         └────────┬─────────┘
                                  │ HTTP/HTTPS
                         ┌────────▼─────────┐
                         │      Nginx       │
                         │ Reverse Proxy    │
                         └────────┬─────────┘
                                  │
                         ┌────────▼─────────┐
                         │   Express CRM    │──────► PostgreSQL
                         │ Website + API    │              │
                         └────────┬─────────┘           pgAdmin
                                  │ /metrics
              ┌───────────────────┼──────────────────────┐
              ▼                   ▼                      ▼
         Prometheus          cAdvisor/exporters       Prometheus
              │
              ▼
           Grafana ◄────────── Loki ◄────────── Promtail
                                                    ▲
                                          log các container
```

Prometheus scrape metrics của ứng dụng, Nginx, PostgreSQL exporter và cAdvisor. Promtail đọc log các container và gửi tới Loki; Grafana dùng Prometheus và Loki làm data source. Chỉ Nginx cần nhận kết nối website từ bên ngoài; database và exporter ở mạng nội bộ.

## 4. Thiết kế dữ liệu dự kiến

| Bảng | Mục đích | Trường chính gợi ý |
|---|---|---|
| `users` | Tài khoản ứng dụng (nếu triển khai đăng nhập) | `id`, `name`, `email`, `password_hash`, `role`, `created_at` |
| `customers` | Tổ chức/cá nhân được CRM quản lý | `id`, `name`, `company_name`, `industry`, `email`, `phone`, `address`, `status`, `created_at`, `updated_at` |
| `contacts` | Người liên hệ của khách hàng | `id`, `customer_id`, `first_name`, `last_name`, `job_title`, `email`, `phone`, `is_primary`, `created_at` |
| `interactions` | Lịch sử chăm sóc/tương tác | `id`, `customer_id`, `contact_id`, `user_id`, `type`, `subject`, `notes`, `occurred_at`, `created_at` |

### Quy tắc dữ liệu quan trọng

- `contacts.customer_id` tham chiếu `customers.id`; một khách hàng có thể có nhiều liên hệ.
- `interactions.customer_id` bắt buộc tham chiếu khách hàng; `contact_id` có thể để trống nếu tương tác không gắn với một người cụ thể.
- `type` chỉ nhận các giá trị hợp lệ như `call`, `email`, `meeting`, `note`.
- Xác thực email, số điện thoại, trạng thái và các trường bắt buộc ở phía server.
- Dùng parameterized query hoặc ORM để tránh SQL injection.
- Chọn và ghi rõ quy tắc xóa dữ liệu liên quan: chặn xóa khách hàng còn liên hệ/tương tác, hoặc dùng xóa mềm (`deleted_at`) để giữ lịch sử CRM.
- Mật khẩu (nếu có đăng nhập) chỉ lưu dưới dạng hash; không lưu plaintext.

## 5. Cấu trúc repository

Tên repository đề xuất: `MSSV-crm-customer-care`, thay `MSSV` bằng mã số sinh viên theo quy định môn học.

```text
MSSV-crm-customer-care/
├── app/
│   ├── src/
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── services/
│   │   ├── middleware/
│   │   ├── views/ hoặc public/
│   │   └── server.js
│   ├── package.json
│   ├── package-lock.json
│   └── Dockerfile
├── database/
│   ├── init.sql
│   └── sample-data.sql
├── nginx/
│   ├── nginx.conf
│   └── certs/
│       └── .gitkeep
├── monitoring/
│   ├── prometheus/prometheus.yml
│   ├── grafana/provisioning/
│   ├── postgres-exporter/
│   └── nginx-exporter/
├── logging/
│   ├── loki/loki-config.yml
│   └── promtail/promtail-config.yml
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
└── KE_HOACH_HE_THONG_CRM_CHAM_SOC_KHACH_HANG.md
```

## 6. Kế hoạch triển khai

### Giai đoạn 0 — Chuẩn bị

1. Tạo tài khoản GitHub theo yêu cầu môn học, ưu tiên tên/mã số sinh viên.
2. Tạo repository theo tên quy định; khởi tạo nhánh `main` và README.
3. Cài Git, Docker Desktop và Docker Compose.
4. Tạo cấu trúc thư mục, `.gitignore`, `.env.example`.
5. Đặt `.env` trong `.gitignore`; chỉ commit file mẫu với giá trị minh họa, không dùng secret thật.

Biến môi trường dự kiến:

```env
POSTGRES_DB=crm_db
POSTGRES_USER=crm_admin
POSTGRES_PASSWORD=replace_with_strong_admin_password
CRM_APP_USER=crm_app
CRM_APP_PASSWORD=replace_with_strong_app_password
APP_PORT=3000
PGADMIN_DEFAULT_EMAIL=admin@example.test
PGADMIN_DEFAULT_PASSWORD=replace_with_strong_password
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=replace_with_strong_password
```

### Giai đoạn 1 — Ứng dụng CRM và PostgreSQL

1. Khởi tạo Express application và giao diện CRM.
2. Tạo schema PostgreSQL cho khách hàng, liên hệ và tương tác; thêm dữ liệu mẫu để demo ngay sau khi khởi động.
3. Xây dựng các trang/API: danh sách/chi tiết khách hàng, CRUD khách hàng, CRUD liên hệ, ghi và xem lịch sử tương tác, tìm kiếm/lọc.
4. Kết nối ứng dụng với PostgreSQL qua biến môi trường; tạo `GET /health` để healthcheck.
5. Viết Dockerfile cho app và cấu hình Compose cho `app`, `postgres`, `pgadmin`.
6. Tạo PostgreSQL volume để dữ liệu còn nguyên sau khi restart/recreate container.
7. Kiểm tra thao tác trên giao diện và xác nhận bản ghi hiện trong pgAdmin.

### Giai đoạn 2 — Nginx reverse proxy và bảo vệ cơ bản

1. Thêm service `nginx`, chuyển tiếp request tới `app:3000` bằng tên service Docker.
2. Truy cập website qua Nginx; không expose trực tiếp cổng ứng dụng nếu không cần.
3. Cấu hình HTTPS tự ký **hoặc** tối thiểu security headers cơ bản theo yêu cầu môn học.
4. Không public cổng PostgreSQL; chỉ các service cần thiết mới ở cùng mạng với DB.
5. Có thể bind giao diện pgAdmin/Grafana vào localhost cho demo trên máy cá nhân.

Security headers tham khảo (điều chỉnh CSP theo tài nguyên của giao diện):

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self';" always;
```

Chỉ bật HSTS khi đã cấu hình HTTPS phù hợp. Với HTTPS tự ký, trình duyệt có thể hiển thị cảnh báo chứng chỉ trong môi trường demo.

**Commit 1 bắt buộc — Nginx reverse proxy:**

```text
feat: configure nginx reverse proxy and security headers
```

Commit này cần chứa cấu hình Nginx và phần HTTPS tự ký hoặc security headers; có thể kèm Docker Compose cần thiết để Nginx chạy. Tài liệu môn học đánh dấu cấu hình Nginx là mốc commit 1.

### Giai đoạn 3 — Prometheus và Grafana

1. Cài `prom-client` và tạo endpoint `GET /metrics` cho Express.
2. Ghi nhận tối thiểu tổng HTTP requests, thời gian phản hồi, lỗi HTTP 4xx/5xx và số khách hàng/tương tác được tạo (nếu triển khai metric nghiệp vụ).
3. Thêm Prometheus và cấu hình scrape targets cho app, Nginx exporter, PostgreSQL exporter, cAdvisor.
4. Thêm postgres-exporter với tài khoản giám sát quyền giới hạn; thêm nginx-prometheus-exporter đọc `stub_status`.
5. Thêm cAdvisor để lấy CPU/RAM/network/filesystem của container.
6. Thêm Grafana, cấu hình Prometheus làm data source và tạo dashboard.
7. Xác minh targets hiện `UP`; tạo traffic vào app để dashboard có dữ liệu.

Scrape targets gợi ý:

```yaml
scrape_configs:
  - job_name: crm-app
    static_configs:
      - targets: ["app:3000"]
  - job_name: nginx
    static_configs:
      - targets: ["nginx-exporter:9113"]
  - job_name: postgres
    static_configs:
      - targets: ["postgres-exporter:9187"]
  - job_name: cadvisor
    static_configs:
      - targets: ["cadvisor:8080"]
```

**Commit 2 bắt buộc — Prometheus + Grafana:**

```text
feat: add prometheus grafana and service monitoring
```

Commit này gồm cấu hình Prometheus, Grafana/dashboard, exporter và các cập nhật Compose liên quan. Dashboard phải thể hiện được metrics container, web server/app và database.

### Giai đoạn 4 — Loki, Promtail và LogQL

1. Thêm Loki để nhận và lưu log tập trung.
2. Thêm Promtail để đọc log container và gửi đến Loki; gán nhãn service dễ nhận biết, ví dụ `service="app"`, `service="nginx"`, `service="postgres"`.
3. Ghi log có ích cho các sự kiện CRM: tạo/cập nhật khách hàng, thêm liên hệ, ghi tương tác, lỗi request và lỗi database. Không ghi password, token hoặc dữ liệu nhạy cảm.
4. Cấu hình Loki làm data source trong Grafana; mở Grafana Explore để kiểm tra log.
5. Chạy tối thiểu 2–3 câu LogQL và chụp ảnh query cùng kết quả.

Ví dụ dưới đây giả sử nhãn Promtail là `service`; thay bằng đúng nhãn cấu hình thực tế:

```logql
{service="app"} |= "customer_created"
```

Tìm sự kiện tạo khách hàng.

```logql
{service="app"} |= "ERROR"
```

Tìm lỗi trong log ứng dụng.

```logql
{service="nginx"} |~ " 4[0-9]{2} | 5[0-9]{2} "
```

Tìm request HTTP lỗi 4xx/5xx nếu định dạng access log Nginx có status code tương ứng.

**Commit 3 bắt buộc — Loki + Promtail:**

```text
feat: add centralized logging with loki and promtail
```

Commit này gồm cấu hình Loki, Promtail, Grafana datasource nếu provision tự động và các cập nhật Compose liên quan. Tài liệu yêu cầu ít nhất 2–3 truy vấn LogQL cơ bản.

### Giai đoạn 5 — Hardening hệ thống

Áp dụng tối thiểu 3–4 biện pháp và ghi rõ vị trí cấu hình để có thể trình bày:

- Chạy ứng dụng bằng user không phải `root`; kiểm tra image và user thực tế của container.
- Dùng Docker network riêng; PostgreSQL chỉ nằm trong mạng nội bộ, không publish cổng DB ra Internet.
- Dùng mật khẩu mạnh qua `.env` không commit; dùng DB role riêng cho ứng dụng với quyền tối thiểu, không kết nối bằng superuser.
- Cấu hình security headers tại Nginx; chỉ bật HSTS nếu dùng HTTPS.
- Hạn chế quyền ghi/capabilities của container khi image và ứng dụng hỗ trợ; không mount quyền host không cần thiết.
- Không public pgAdmin, Grafana, Prometheus, Loki và exporter ra Internet; giới hạn cổng demo về localhost khi phù hợp.
- Dùng parameterized query, validate dữ liệu đầu vào, trả lỗi thân thiện thay vì stack trace.
- Không ghi secret hoặc dữ liệu nhạy cảm vào ứng dụng logs.

### Giai đoạn 6 — README và GitHub

README cần có:

1. Mô tả bài toán CRM và chức năng chính.
2. Sơ đồ kiến trúc, danh sách service/công nghệ.
3. Yêu cầu môi trường và hướng dẫn clone repository.
4. Cách tạo `.env` từ `.env.example` và cấu hình an toàn.
5. Lệnh khởi chạy/dừng Compose, ví dụ `docker compose up -d --build` và `docker compose down`.
6. URL website, pgAdmin, Grafana; thông tin demo an toàn nếu cần.
7. Cách kiểm tra dữ liệu trên pgAdmin, targets Prometheus, dashboard và truy vấn LogQL.
8. Hướng dẫn khắc phục lỗi khởi động thường gặp và lưu ý bảo mật.
9. Ảnh chụp giao diện và các màn hình minh chứng.

Phải có ít nhất ba commit có nội dung rõ ràng. Các mốc commit kỹ thuật cần thể hiện riêng: **Commit 1 Nginx**, **Commit 2 Prometheus + Grafana**, **Commit 3 Loki + Promtail**. Có thể tạo thêm commit nền tảng ứng dụng/DB trước các mốc này; không gộp đến mức khó nhận ra ba mốc yêu cầu.

### Giai đoạn 7 — Báo cáo tổng hợp

Tài liệu môn học yêu cầu báo cáo tối thiểu 10 trang, bìa có thông tin sinh viên và chủ đề, mô tả cấu trúc/cách hoạt động hệ thống và kết quả của các bước, kèm hình minh họa. Gợi ý bố cục:

1. Bìa chuẩn báo cáo: trường/khoa, môn học, đề tài CRM, sinh viên, mã số, giảng viên, thời gian.
2. Mục lục, mục tiêu và phạm vi bài toán.
3. Công nghệ sử dụng và sơ đồ kiến trúc.
4. Phân tích chức năng và thiết kế dữ liệu.
5. Hướng dẫn chức năng CRM, kèm ảnh khách hàng/liên hệ/lịch sử tương tác.
6. Docker Compose, PostgreSQL, volume và kết quả kiểm tra trên pgAdmin.
7. Cấu hình Nginx, reverse proxy và HTTPS hoặc security headers.
8. Prometheus targets, metrics và dashboard Grafana cho app/web/DB/container.
9. Loki, Promtail và 2–3 truy vấn LogQL có kết quả.
10. Hardening đã thực hiện, cách demo, kết luận và hướng phát triển.

Ảnh cần chụp từ hệ thống thực sự chạy; thêm chú thích nói rõ ảnh chứng minh phần nào. Không dùng ảnh minh họa thay cho kết quả triển khai.

## 7. Kiểm thử và nghiệm thu

### 7.1. Kiểm tra chức năng CRM

- [ ] Danh sách khách hàng đọc dữ liệu từ PostgreSQL.
- [ ] Tạo, sửa, xóa hoặc xóa mềm và tìm kiếm/lọc khách hàng hoạt động.
- [ ] Tạo/sửa/xóa liên hệ; liên hệ gắn đúng khách hàng.
- [ ] Ghi tương tác với loại, nội dung và thời điểm; lịch sử hiển thị đúng khách hàng.
- [ ] Dữ liệu vẫn còn sau khi restart/recreate container nhờ volume.
- [ ] pgAdmin kết nối được và hiển thị các bảng/dữ liệu mẫu.

### 7.2. Kiểm tra hạ tầng và bảo mật

- [ ] `docker compose up -d --build` chạy toàn bộ stack.
- [ ] Website truy cập qua Nginx reverse proxy.
- [ ] HTTPS tự ký hoạt động hoặc response có security headers cơ bản.
- [ ] PostgreSQL không được expose công khai không cần thiết.
- [ ] `.env`, mật khẩu thật và private key không nằm trong repository.
- [ ] Có tối thiểu 3–4 biện pháp hardening thực sự cấu hình được.

### 7.3. Kiểm tra monitoring và logging

- [ ] Prometheus targets cho app, web server, DB và container ở trạng thái `UP`.
- [ ] Grafana dashboard hiển thị metrics của container, web/app và PostgreSQL.
- [ ] Loki nhận log từ app và Nginx (có thể thêm DB).
- [ ] Chạy được tối thiểu 2–3 truy vấn LogQL và có kết quả.

### 7.4. Kiểm tra trình bày

- [ ] Có thể demo từ trình duyệt CRM qua Nginx, tạo khách hàng/liên hệ/tương tác.
- [ ] Chứng minh dữ liệu qua pgAdmin.
- [ ] Chứng minh metrics trên Grafana và log trên Grafana Explore.
- [ ] Giải thích được kiến trúc, luồng request, luồng metrics/log và các biện pháp hardening.
- [ ] Có repository, README, báo cáo tối thiểu 10 trang và screenshot/minh chứng.

## 8. Minh chứng cần chuẩn bị để nộp/demo

1. Link GitHub repository có source, file Compose, cấu hình và README.
2. Ảnh dashboard CRM: danh sách/chi tiết khách hàng, danh sách liên hệ và lịch sử tương tác.
3. Ảnh pgAdmin cho thấy bảng và dữ liệu đã lưu.
4. Ảnh cấu hình hoặc kết quả kiểm tra website qua Nginx; header hoặc HTTPS.
5. Ảnh Docker containers đang chạy.
6. Ảnh Prometheus Targets có các target cần thiết ở trạng thái `UP`.
7. Ảnh Grafana dashboard có metrics app/web, PostgreSQL và container.
8. Ảnh Grafana Explore với 2–3 truy vấn LogQL cùng kết quả.
9. Ảnh hoặc nội dung Git history thể hiện ba commit mốc Nginx, Prometheus/Grafana, Loki/Promtail.
10. Ảnh/trích đoạn cấu hình minh chứng ít nhất 3–4 biện pháp hardening.

## 9. Kịch bản demo gợi ý

1. Chạy `docker compose ps` để cho thấy các service hoạt động.
2. Mở website qua địa chỉ Nginx; tạo một khách hàng mẫu.
3. Mở chi tiết khách hàng, thêm liên hệ rồi ghi một cuộc gọi hoặc cuộc họp.
4. Làm mới trang để cho thấy dữ liệu được lưu; mở pgAdmin kiểm tra các bảng liên quan.
5. Tạo một số request vào app; mở Prometheus Targets và Grafana dashboard để trình bày metrics.
6. Mở Grafana Explore, chạy các truy vấn LogQL và giải thích log trả về.
7. Chỉ ra cấu hình non-root, mạng nội bộ/không public DB, secrets trong `.env` và security headers.
8. Kết thúc bằng README và lịch sử ba commit mốc.

## 10. Ma trận tiêu chí đánh giá

| Tiêu chí | Điểm | Nội dung cần đạt | Bằng chứng nên mở khi chấm |
|---|---:|---|---|
| Quản lý mã nguồn trên GitHub | 1.5 | Repository có source + cấu hình; ít nhất 3 commit rõ ràng; README hướng dẫn chạy | GitHub, README, lịch sử commit |
| Triển khai ứng dụng + Database | 1.5 | CRM ổn định, kết nối PostgreSQL thành công, pgAdmin hoạt động | Website, pgAdmin, dữ liệu CRUD |
| Nginx Reverse Proxy | 1.5 | Truy cập website qua Nginx; HTTPS tự ký hoặc security headers cơ bản | URL demo, Nginx config, headers/chứng chỉ |
| Prometheus + Grafana | 1.5 | Metrics được thu thập; dashboard giám sát container, web và DB | Prometheus Targets, Grafana dashboard |
| Loki + Promtail | 1.5 | Log tập trung hoạt động; truy vấn được ít nhất 2–3 câu LogQL | Grafana Explore với query và kết quả |
| Hardening hệ thống | 1.5 | Ít nhất 3–4 biện pháp như non-root, network isolation, mật khẩu mạnh, giới hạn quyền DB, headers | Compose, Dockerfile, `.gitignore`, Nginx config |
| Tổng thể và trình bày | 1.0 | Stack chạy bằng Docker Compose; demo rõ, có screenshot/minh chứng và hiểu bài | Demo trực tiếp, báo cáo và ảnh |
| **Tổng** | **10.0** |  |  |

## 11. Tiêu chí hoàn thành

Đề tài sẵn sàng nộp khi:

- CRM quản lý được khách hàng, liên hệ và lịch sử tương tác; PostgreSQL lưu dữ liệu bền vững và pgAdmin kiểm tra được.
- Toàn bộ stack khởi chạy bằng Docker Compose; người chấm làm theo README có thể chạy lại.
- Nginx proxy đúng và có HTTPS tự ký hoặc security headers cơ bản.
- Prometheus thu metrics của ứng dụng, web server, DB và container; Grafana có dashboard tương ứng.
- Promtail gửi log tới Loki và có ít nhất 2–3 truy vấn LogQL chạy được.
- Có ít nhất 3–4 biện pháp hardening được cấu hình, không chỉ liệt kê trong báo cáo.
- GitHub có README, source/configuration và ba commit mốc đúng thứ tự nội dung.
- Báo cáo từ 10 trang trở lên có bìa, mô tả hệ thống, kết quả từng bước và ảnh minh chứng.
- Demo được luồng CRUD CRM, kiểm tra DB, dashboard, LogQL và giải thích được các thành phần.
