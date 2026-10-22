# Kế hoạch chia task cho AI agent — CRM trên Ubuntu

## 1. Mục tiêu và cách dùng

Tài liệu này chia đề tài **Hệ thống CRM Chăm sóc Khách hàng** thành các gói việc độc lập để giao cho nhiều AI agent hoặc thực hiện lần lượt. Mục tiêu là hoàn thành ứng dụng CRM, PostgreSQL/pgAdmin, Nginx, Prometheus/Grafana, Loki/Promtail, hardening, GitHub, báo cáo và demo trên Ubuntu.

Đây là kế hoạch giao việc; các agent không nên tự ý thay đổi phạm vi đề tài, công nghệ đã thống nhất, thông tin bí mật hay bằng chứng triển khai. Người điều phối (bạn) giữ quyền tích hợp, chạy Docker Compose trên Ubuntu, xử lý xung đột, xác nhận kết quả thật và chụp ảnh báo cáo.

## 2. Quy tắc làm việc với agent

- Trước khi giao việc, đưa cho agent này file kế hoạch CRM chính và phần “Hợp đồng tích hợp” ở mục 4.
- Mỗi agent chỉ sửa các thư mục/file được giao; không tự sửa `docker-compose.yml`, `.env`, README tổng thể hoặc file của agent khác trừ khi được yêu cầu.
- Yêu cầu agent trả về: file đã sửa/tạo, các quyết định kỹ thuật, lệnh cần chạy, cách kiểm tra, kết quả kiểm tra đã thực sự làm và những điểm còn thiếu. Không chấp nhận tuyên bố “đã kiểm tra” nếu agent chưa chạy lệnh đó.
- Không để agent commit/push lên GitHub nếu bạn chưa chủ động giao quyền đó. Bạn review và tích hợp các thay đổi trước.
- Mỗi task cần ghi rõ đầu vào, đầu ra, tiêu chí hoàn tất và giới hạn. Tránh giao chung chung kiểu “làm toàn bộ hệ thống”.
- Có thể chạy song song các agent không đụng cùng file. Với tối đa 4 agent hoạt động cùng lúc, dùng một agent điều phối và không quá 3 agent triển khai song song ở một đợt.
- Agent không được đưa mật khẩu thật, token, private key hoặc dữ liệu cá nhân vào source, log, prompt công khai hay ảnh chụp.

## 3. Phân chia vai trò

| Vai trò | Phạm vi sở hữu | Không sở hữu | Bàn giao |
|---|---|---|---|
| **Bạn — điều phối/tích hợp** | Chốt repo và kiến trúc; giữ `docker-compose.yml`, `.env`, tích hợp; chạy trên Ubuntu; xử lý lỗi liên dịch vụ; GitHub; báo cáo cuối và demo | Không cần giao agent quyền push/commit nếu chưa muốn | Stack chạy được trên Ubuntu, lịch sử commit, ảnh thật và bản nộp |
| **Agent A — CRM app + PostgreSQL schema** | `app/**`, `database/**`; giao diện/API CRM, Dockerfile app, health/metrics endpoint và log app | Compose, Nginx, monitoring, logging collector, README tổng thể | Ứng dụng, schema/seed, mô tả API và cách chạy riêng |
| **Agent B — Nginx** | `nginx/**`; reverse proxy, headers hoặc HTTPS cấu hình | App source, Compose tổng thể, secrets, dashboard | Nginx config và các bước kiểm tra proxy/headers |
| **Agent C — Prometheus/Grafana** | `monitoring/**`; scrape config, provisioning/dashboard, cấu hình exporter nếu chia rõ | Compose tổng thể, app, Nginx config, Loki/Promtail | Cấu hình monitoring, targets dự kiến và panel cần có |
| **Agent D — Loki/Promtail** | `logging/**`; Loki config, Promtail config, nhãn log và ví dụ LogQL | Compose tổng thể, app logger implementation, monitoring | Config logging và truy vấn LogQL; chỉ rõ label cần từ Docker/Promtail |
| **Agent E — tài liệu/báo cáo** | Bản nháp README/báo cáo/checklist sau khi có kết quả tích hợp | Không tự tạo ảnh giả, không khẳng định thành phần đã chạy nếu chưa có bằng chứng | README/báo cáo có chỗ đánh dấu bằng chứng còn chờ bạn chụp |

Agent E nên làm sau khi các phần đã tích hợp để tài liệu mô tả đúng trạng thái thực. Nếu thời gian gấp, cho agent E chuẩn bị khung README/báo cáo trước, nhưng mọi thông tin kết quả thực tế phải được bạn cập nhật.

## 4. Hợp đồng tích hợp — chốt trước khi giao agent

Để các thành phần ghép được mà không phải đoán tên service, port hoặc label, thống nhất các giá trị dưới đây trước. Có thể đổi một lần trước khi bắt đầu, sau đó không đổi riêng lẻ giữa chừng.

| Mục | Giá trị thống nhất |
|---|---|
| Ứng dụng | Node.js + Express, container/service `app` |
| Cổng trong container app | `3000` |
| PostgreSQL service | `db`, port nội bộ `5432` |
| Tên DB/user ứng dụng | `crm_db` / `crm_app` (qua biến môi trường) |
| pgAdmin service | `pgadmin`, cổng container `80` |
| Nginx service | `nginx`, cổng container `80` (và `443` nếu bật TLS) |
| Health endpoint | `GET /health`, trả mã `200` khi ứng dụng sẵn sàng và kiểm tra DB đạt |
| Metrics endpoint | `GET /metrics`, định dạng Prometheus tại `app:3000/metrics` |
| Log ứng dụng | stdout/stderr, một sự kiện mỗi dòng; ưu tiên JSON; không ghi secret/PII không cần thiết |
| Tên label LogQL | Thống nhất nhãn `service` với giá trị `app`, `nginx`, `db` nếu Promtail có thể gắn nhãn đó |
| URL app | Truy cập từ host qua cổng Nginx; không truy cập thẳng app trong demo thông thường |
| File Compose | Bạn là người tích hợp và sở hữu `docker-compose.yml` |
| Networks | Tối thiểu `edge`, `data`, `monitoring`; DB không publish port ra host |

**Lưu ý:** cAdvisor thường cần quyền đọc thông tin host/container. Chỉ thêm các mount/quyền cần thiết, ghi rõ trong báo cáo và không publish giao diện exporter ra ngoài. Nếu cấu hình Promtail phải đọc Docker logs qua socket hoặc thư mục log host, giới hạn mount và quyền ở mức có thể, không biến socket thành cổng truy cập công khai.

## 5. Thứ tự công việc và phụ thuộc

### Pha 0 — Bạn chốt nền tảng

1. Tạo repository GitHub theo mã số sinh viên; clone trên Ubuntu.
2. Cài/kiểm tra Git, Docker Engine và Docker Compose plugin; xác nhận `docker --version` và `docker compose version` chạy được.
3. Tạo skeleton thư mục và file `.gitignore`; tạo `.env.example` không có secret thật.
4. Chốt hợp đồng tích hợp ở mục 4 rồi gửi cùng kế hoạch CRM chính cho agent.
5. Tạo commit nền tảng nếu cần, ví dụ `chore: initialize crm project structure`.

### Pha 1 — Chạy app và DB tối thiểu (Agent A, sau đó bạn)

Agent A làm app/schema trước. Bạn tích hợp tạm `app`, `db`, `pgadmin` vào Compose và chạy trên Ubuntu. Chỉ khi app CRUD được và dữ liệu còn sau khi restart thì mới chuyển sang observability.

**Cổng nghiệm thu 1:** tạo khách hàng, thêm liên hệ, ghi một tương tác; đọc lại dữ liệu trên giao diện và pgAdmin; dữ liệu tồn tại sau restart container.

### Pha 2 — Chia song song các cấu hình hạ tầng (Agent B, C, D)

Sau khi hợp đồng tích hợp đã chốt, có thể giao song song:

- Agent B làm Nginx reverse proxy và headers/HTTPS trong `nginx/**`.
- Agent C làm Prometheus/Grafana config trong `monitoring/**`, dựa trên tên service/exporter ở hợp đồng.
- Agent D làm Loki/Promtail config trong `logging/**`, dựa trên stdout logs và label đã thống nhất.

Agent C và D chỉ bàn giao config; bạn ghép service vào Compose. Nếu exporter cần quyền hoặc mount đặc biệt, agent phải ghi rõ lý do và mức quyền.

**Cổng nghiệm thu 2:** website qua Nginx; response có headers hoặc TLS; targets cần thiết lên `UP`; có dashboard với số liệu; Loki nhận app/Nginx logs và LogQL có kết quả.

### Pha 3 — Hardening và hoàn thiện bằng chứng (Bạn + agent phù hợp)

1. Kiểm tra user thực tế từng container và chuyển app sang non-root nếu khả thi.
2. Xác nhận DB không publish port; giới hạn network; dùng DB user ứng dụng quyền thấp.
3. Xác nhận `.env`, key/cert private và mật khẩu không tracked bởi Git.
4. Giới hạn các giao diện pgAdmin/Grafana/Prometheus ở localhost hoặc mạng demo.
5. Chạy luồng demo từ đầu đến cuối; chụp screenshot thật.

### Pha 4 — Tài liệu, báo cáo, Git (Agent E + bạn)

Agent E soạn README và khung báo cáo từ cấu hình/kết quả đã tích hợp. Bạn bổ sung mã sinh viên, thông tin bìa, URL repo, dữ liệu/ảnh thật, xác nhận báo cáo ít nhất 10 trang và kiểm tra không có placeholder.

Tạo ba commit kỹ thuật rõ ràng theo yêu cầu môn học:

1. **Commit 1:** Nginx reverse proxy + HTTPS tự ký hoặc security headers.
2. **Commit 2:** Prometheus + Grafana giám sát container/web/DB.
3. **Commit 3:** Loki + Promtail + LogQL.

Có thể có commit ứng dụng/DB trước đó. Tránh gom cả ba mốc vào một commit cuối vì rubric cần nhận ra nội dung các mốc.

## 6. Prompt giao việc mẫu cho từng agent

### Agent A — ứng dụng CRM và schema

```text
Bạn phụ trách phần ứng dụng CRM và schema PostgreSQL cho đề tài “Hệ thống CRM Chăm sóc Khách hàng”. Đọc file KE_HOACH_HE_THONG_CRM_CHAM_SOC_KHACH_HANG.md và tuân thủ hợp đồng tích hợp: Express service app, cổng container 3000, PostgreSQL service db, GET /health, GET /metrics. Chỉ sửa app/** và database/**; không sửa docker-compose.yml, .env, nginx/**, monitoring/**, logging/** hoặc README tổng thể.

Hãy triển khai CRUD khách hàng, liên hệ của khách hàng, lịch sử tương tác; tìm kiếm/lọc cơ bản; schema có foreign key và dữ liệu seed. Dùng parameterized query/ORM, validate input, xử lý lỗi không lộ stack trace, chạy app bằng non-root trong Dockerfile nếu khả thi. App phải log ra stdout/stderr (ưu tiên JSON, một event mỗi dòng, không ghi secret), có /health kiểm tra app/DB và /metrics Prometheus. Trả về danh sách file, quyết định schema/API, lệnh build/run cần thiết, cách kiểm tra và kết 결과 kiểm tra thực tế; ghi rõ phần nào chưa chạy được. Đừng tạo mật khẩu thật.
```

### Agent B — Nginx reverse proxy

```text
Bạn phụ trách Nginx cho đề tài CRM. Đọc kế hoạch CRM và hợp đồng tích hợp: app có service name app, cổng 3000; Nginx sẽ được tôi ghép vào docker-compose.yml. Chỉ sửa nginx/**; không sửa Compose, app, monitoring, logging, .env hay README tổng thể.

Tạo cấu hình reverse proxy cho website, giữ các header proxy cần thiết, thêm security headers cơ bản (CSP phải tương thích với giao diện hoặc giải thích cách chỉnh). Không bật HSTS trừ khi cấu hình HTTPS được chọn. Không đưa private key hoặc secret vào Git. Bàn giao lệnh kiểm tra config, cách xác minh website được proxy và cách kiểm tra headers; ghi rõ nếu HTTPS tự ký cần thao tác nào. Không khẳng định đã chạy trên Ubuntu nếu bạn chưa chạy.
```

### Agent C — Prometheus/Grafana

```text
Bạn phụ trách cấu hình Prometheus/Grafana CRM. Đọc kế hoạch CRM và hợp đồng tích hợp: app:3000/metrics, service db là PostgreSQL, Nginx exporter, postgres-exporter, cAdvisor sẽ được tôi thêm vào Compose. Chỉ sửa monitoring/**; không sửa docker-compose.yml, app, nginx/**, logging/** hoặc .env.

Tạo prometheus.yml scrape config, Grafana provisioning/data source, dashboard provisioning (JSON/YAML) để quan sát app/web, PostgreSQL và container. Nêu chính xác target names/ports mà Compose cần cung cấp. Dashboard cần có panel hữu ích và query PromQL phù hợp. Hạn chế quyền exporter, không thêm credentials thật vào config. Bàn giao cách kiểm tra targets UP và dashboard; ghi rõ mọi target chưa thể xác minh.
```

### Agent D — Loki/Promtail/LogQL

```text
Bạn phụ trách logging tập trung CRM. Đọc kế hoạch CRM và hợp đồng tích hợp: app log ra stdout/stderr, service names app/nginx/db, nhãn LogQL thống nhất service=app|nginx|db. Tôi sẽ ghép service vào Compose. Chỉ sửa logging/**; không sửa Compose, app, nginx/**, monitoring/**, .env hay README tổng thể.

Tạo cấu hình Loki và Promtail để thu log Docker phù hợp với Ubuntu/Docker Compose, thêm nhãn ổn định, không ghi lộ secret/PII. Chuẩn bị 3 truy vấn LogQL chạy được với định dạng log đã thống nhất: sự kiện customer_created, lỗi app, request 4xx/5xx Nginx. Nêu rõ các mount/quyền cần trong Compose và rủi ro/quyền tối thiểu. Bàn giao cách xác minh log trong Grafana Explore và chỉ báo kết quả nào chưa được chạy thật.
```

### Agent E — README và báo cáo

```text
Bạn phụ trách soạn README và khung báo cáo cho CRM trên Ubuntu. Đọc kế hoạch CRM, tiêu chí chấm điểm và các file source/config đã tích hợp. Chỉ sửa README.md và thư mục báo cáo được tôi chỉ định; không sửa code/Compose. Không tự tạo ảnh hoặc tuyên bố thành phần chạy thành công nếu chưa có bằng chứng thật.

README cần có hướng dẫn cài điều kiện, cấu hình .env từ .env.example, docker compose up/down, URL, pgAdmin, Grafana, Prometheus, LogQL, xử lý lỗi và bảo mật. Báo cáo tối thiểu 10 trang cần bìa, kiến trúc, DB, app, Nginx, monitoring, logging, hardening, kết luận và vị trí chèn screenshot thật. Dùng placeholder rõ ràng cho nội dung/ảnh mà tôi cần cung cấp; trả lại checklist placeholder còn thiếu.
```

## 7. Checklist tích hợp trên Ubuntu

### Trước khi khởi chạy

- [ ] Clone repository và vào đúng thư mục dự án.
- [ ] Tạo `.env` từ `.env.example`; đặt mật khẩu mạnh riêng, không gửi secret vào agent.
- [ ] Kiểm tra không có file `.env`, private key hoặc mật khẩu thật bị Git theo dõi.
- [ ] Chạy kiểm tra cú pháp Compose (`docker compose config`) và sửa lỗi cấu hình trước khi khởi động.

### Khởi chạy và quan sát

- [ ] Chạy `docker compose up -d --build`.
- [ ] Chạy `docker compose ps` và xem log khởi động bằng `docker compose logs --tail=100`.
- [ ] Mở CRM qua Nginx; tạo khách hàng, liên hệ và tương tác.
- [ ] Mở pgAdmin, kết nối PostgreSQL bằng tên service `db` và kiểm tra bản ghi.
- [ ] Restart app/DB, xác nhận volume giữ dữ liệu.
- [ ] Mở Prometheus targets, kiểm tra `UP`; mở Grafana dashboard.
- [ ] Trong Grafana Explore chọn Loki và chạy 2–3 LogQL sau khi tạo log mẫu.
- [ ] Kiểm tra response headers/TLS và chứng minh các biện pháp hardening.
- [ ] Tắt stack bằng `docker compose down` (không xóa volume khi cần giữ dữ liệu).

Các lệnh trên là checklist thao tác để bạn chạy và xác minh trên máy Ubuntu; kế hoạch này không khẳng định chúng đã được thực thi.

## 8. Rủi ro phụ thuộc và cách xử lý

| Rủi ro | Dấu hiệu | Cách xử lý |
|---|---|---|
| Tên service/port không thống nhất | Prometheus target `DOWN`, Nginx `502`, app không kết nối DB | Quay về hợp đồng mục 4; sửa config một đầu mối rồi ghi lại thay đổi |
| Metrics endpoint chưa có | Prometheus không scrape được app | Hoàn tất `/metrics` trong Agent A trước khi nhận cấu hình monitoring |
| Log label khác ví dụ | LogQL trả về rỗng dù Loki có dữ liệu | Mở Explore xem labels thực tế; chỉnh query hoặc Promtail labels cho đồng nhất |
| Agent cùng sửa một file | Conflict hoặc cấu hình bị ghi đè | Giữ Compose/README tổng thể cho bạn; giao thư mục riêng; tích hợp theo pha |
| pgAdmin/Exporter cần secret | Secret bị commit nhầm | Dùng `.env`, `.gitignore`, user DB quyền thấp; thay secret nếu đã lộ |
| Dashboard không có dữ liệu | Target chưa `UP`, không có traffic, sai metric name | Kiểm tra scrape trước, tạo request mẫu, sửa PromQL theo metrics thực tế |
| Docker host permissions quá rộng | Compose mount Docker socket hoặc host path | Chỉ dùng khi cần cho cAdvisor/Promtail; giới hạn quyền/mount, không expose endpoint |
| Báo cáo có kết quả chưa xác minh | Ảnh thiếu hoặc nội dung khẳng định quá sớm | Agent E để placeholder; bạn chỉ điền sau khi tự chạy và chụp ảnh thật |

## 9. Bàn giao cuối cùng

Trước khi kết thúc, bạn cần có:

- [ ] Repository GitHub có source, cấu hình, README và lịch sử commit theo yêu cầu.
- [ ] File kế hoạch CRM chính và file kế hoạch chia task này được lưu cùng dự án hoặc nộp theo yêu cầu giảng viên.
- [ ] CRM hoạt động với khách hàng, liên hệ và lịch sử tương tác.
- [ ] PostgreSQL/pgAdmin, Nginx, Prometheus/Grafana, Loki/Promtail chạy qua Docker Compose.
- [ ] Có 2–3 truy vấn LogQL, dashboard metrics và 3–4 biện pháp hardening được chứng minh.
- [ ] Báo cáo ít nhất 10 trang có ảnh chụp màn hình từ Ubuntu thật.
- [ ] Demo được luồng CRM → DB → metrics → logs và giải thích được kiến trúc.
