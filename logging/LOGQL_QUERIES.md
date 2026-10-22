# Các truy vấn LogQL mẫu cho hệ thống CRM Chăm sóc Khách hàng

Tài liệu này cung cấp các câu lệnh **LogQL** phục vụ chấm điểm và kiểm tra log tập trung qua **Grafana Explore** (Datasource: `Loki`).

---

## 1. Truy vấn 1: Tìm sự kiện tạo khách hàng (`customer_created`)

### Câu lệnh LogQL:
```logql
{service="app"} |= "customer_created"
```

### LogQL dạng JSON nâng cao (trích xuất trường):
```logql
{service="app"} | json | event = "customer_created"
```

### Mục đích:
Xác minh sự kiện nghiệp vụ khi nhân viên tạo mới một khách hàng trên giao diện CRM. Hệ thống Express ghi log cấu trúc JSON:
```json
{"timestamp":"2026-10-22T15:30:00.000Z","level":"info","event":"customer_created","customerId":12,"customerName":"Công ty TNHH Giải pháp Số","service":"crm-app"}
```

---

## 2. Truy vấn 2: Tìm lỗi trong log ứng dụng (`ERROR`)

### Câu lệnh LogQL:
```logql
{service="app"} |= "ERROR"
```

### Câu lệnh LogQL lọc theo level error trong JSON:
```logql
{service="app"} | json | level = "error"
```

### Mục đích:
Phát hiện các lỗi ngoại lệ (exception), lỗi truy vấn database hoặc validation thất bại được ghi lại bởi Error Handler middleware.

---

## 3. Truy vấn 3: Tìm các request HTTP lỗi 4xx / 5xx từ Nginx

### Câu lệnh LogQL (Regex matching HTTP status code):
```logql
{service="nginx"} |~ " 4[0-9]{2} | 5[0-9]{2} "
```

### Mục đích:
Giám sát các request không hợp lệ (404 Not Found, 400 Bad Request, 403 Forbidden) hoặc lỗi máy chủ (500 Internal Server Error, 502 Bad Gateway) được ghi lại trong access log của Nginx Reverse Proxy.

---

## 4. Truy vấn mở rộng bổ sung

### Xem toàn bộ log tương tác khách hàng (`interaction_created`):
```logql
{service="app"} |= "interaction_created"
```

### Xem log các truy vấn từ PostgreSQL:
```logql
{service="db"}
```

### Thống kê số lượng log theo thời gian (Log Rate):
```logql
rate({service="app"}[1m])
```
