# Nhật ký chỉnh sửa và lưu ý triển khai

## Thay đổi đã áp dụng

- `.gitignore`: đổi quy tắc `nginx/certs/` thành `nginx/certs/*` để ngoại lệ `!nginx/certs/.gitkeep` có thể hoạt động. Các file khóa `.key` và `.pem` vẫn bị ignore.
- Tên repository `my-new-project` được giữ nguyên theo yêu cầu.
- Commit khởi tạo hiện tại vẫn chỉ gồm README và tài liệu kế hoạch; chưa có ứng dụng CRM.

## Việc cần sửa trong kế hoạch PostgreSQL trước khi triển khai

Kế hoạch hiện có ví dụ `POSTGRES_USER=crm_app`. Với image PostgreSQL chính thức, `POSTGRES_USER` là superuser khởi tạo; nếu ứng dụng dùng tài khoản này thì không đạt yêu cầu giới hạn quyền. Hãy dùng `POSTGRES_USER=crm_admin` cùng `POSTGRES_PASSWORD` cho tài khoản khởi tạo, tạo `crm_app` riêng qua init SQL, cấp quyền tối thiểu, và cấu hình connection string ứng dụng dùng `CRM_APP_USER`/`CRM_APP_PASSWORD`. `POSTGRES_ADMIN_PASSWORD` không phải biến mặc định của image.

## Xác minh sau khi chỉnh sửa

Chạy `git diff --check`; kiểm tra `git status --short`; xác nhận `nginx/certs/.gitkeep` không bị ignore và khóa riêng vẫn bị ignore. Khi dựng DB, xác nhận app đăng nhập bằng role hạn chế, không phải superuser. Các bước xác minh này chưa được chạy.
