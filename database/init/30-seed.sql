INSERT INTO customers (name, company_name, email, phone, status, industry, address)
VALUES
  ('Nguyễn Minh Anh', 'Công ty Sao Mai', 'minhanh@example.test', '0900000001', 'prospect', 'Công nghệ', 'Hà Nội'),
  ('Trần Quốc Bảo', 'Công ty An Phát', 'quocbao@example.test', '0900000002', 'customer', 'Dịch vụ', 'TP. Hồ Chí Minh');
INSERT INTO contacts (customer_id, first_name, last_name, job_title, email, phone, is_primary)
SELECT id, 'Lê Thu', 'Hà', 'Quản lý mua hàng', 'thuha@example.test', '0900000011', true FROM customers WHERE email='minhanh@example.test';
INSERT INTO interactions (customer_id, type, subject, notes)
SELECT id, 'call', 'Gọi giới thiệu dịch vụ', 'Khách hàng muốn nhận thêm thông tin.' FROM customers WHERE email='minhanh@example.test';
