-- ============================================================
-- Sample Data — Dữ liệu mẫu cho CRM demo
-- ============================================================

-- Customers
INSERT INTO customers (name, company_name, industry, email, phone, address, status, created_at) VALUES
('Nguyễn Văn Minh',  'Công ty TNHH Phần Mềm Sao Việt',           'Công nghệ thông tin', 'minh.nv@saoviet.vn',       '028-3823-4567', '123 Nguyễn Huệ, Quận 1, TP.HCM',          'active',    NOW() - INTERVAL '120 days'),
('Trần Thị Hương',   'Công ty CP Thương mại Đông Á',              'Thương mại',          'huong.tt@dongagroup.vn',   '024-3456-7890', '45 Trần Phú, Ba Đình, Hà Nội',            'active',    NOW() - INTERVAL '95 days'),
('Lê Hoàng Nam',     'Công ty TNHH Sản xuất Hoàng Gia',           'Sản xuất',            'nam.lh@hoanggia-mfg.vn',   '0236-382-1234', '78 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',   'nurturing', NOW() - INTERVAL '60 days'),
('Phạm Thị Mai',     'Tập đoàn Bất động sản Thành Công',          'Bất động sản',        'mai.pt@thanhcong-re.vn',   '028-3917-2345', '200 Lê Lợi, Quận 1, TP.HCM',              'active',    NOW() - INTERVAL '150 days'),
('Võ Đức Thành',     'Công ty TNHH Logistics Toàn Cầu',           'Vận tải & Logistics', 'thanh.vd@globallog.vn',     '028-3856-9012', '56 Nguyễn Thị Minh Khai, Quận 3, TP.HCM', 'lead',      NOW() - INTERVAL '14 days'),
('Đặng Minh Tuấn',   'Công ty CP Giáo dục Tri Thức',              'Giáo dục & Đào tạo',  'tuan.dm@trithuc-edu.vn',   '024-3789-0123', '89 Cầu Giấy, Cầu Giấy, Hà Nội',           'lead',      NOW() - INTERVAL '7 days'),
('Hoàng Thị Lan',    'Công ty TNHH Y tế Sức Khỏe Vàng',           'Y tế & Dược phẩm',   'lan.ht@suckhoevang.vn',    '028-3920-3456', '34 Pasteur, Quận 3, TP.HCM',               'nurturing', NOW() - INTERVAL '45 days'),
('Bùi Quốc Huy',    'Công ty TNHH Thương mại Phương Đông',        'Thương mại',          'huy.bq@phuongdong-tm.vn',  '024-3567-8901', '12 Kim Mã, Ba Đình, Hà Nội',              'inactive',  NOW() - INTERVAL '200 days');

-- Contacts
INSERT INTO contacts (customer_id, first_name, last_name, job_title, email, phone, is_primary) VALUES
-- Sao Việt (customer 1)
(1, 'Nguyễn',  'Văn Minh',  'Giám đốc',                'minh.nv@saoviet.vn',      '0901-234-567', TRUE),
(1, 'Lê',      'Thị Hoa',   'Trưởng phòng IT',         'hoa.lt@saoviet.vn',       '0912-345-678', FALSE),
-- Đông Á (customer 2)
(2, 'Trần',    'Thị Hương', 'Phó Giám đốc',            'huong.tt@dongagroup.vn',  '0923-456-789', TRUE),
(2, 'Ngô',     'Minh Đức',  'Trưởng phòng Mua hàng',   'duc.nm@dongagroup.vn',    '0934-567-890', FALSE),
-- Hoàng Gia (customer 3)
(3, 'Lê',      'Hoàng Nam', 'Giám đốc sản xuất',       'nam.lh@hoanggia-mfg.vn',  '0905-678-901', TRUE),
(3, 'Trương',  'Văn Phúc',  'Kế toán trưởng',          'phuc.tv@hoanggia-mfg.vn', '0916-789-012', FALSE),
-- Thành Công (customer 4)
(4, 'Phạm',    'Thị Mai',   'Chủ tịch HĐQT',           'mai.pt@thanhcong-re.vn',  '0907-890-123', TRUE),
(4, 'Đỗ',      'Thanh Tùng','Giám đốc dự án',          'tung.dt@thanhcong-re.vn', '0918-901-234', FALSE),
(4, 'Vũ',      'Ngọc Anh',  'Trưởng phòng Marketing',  'anh.vn@thanhcong-re.vn',  '0929-012-345', FALSE),
-- Global Logistics (customer 5)
(5, 'Võ',      'Đức Thành', 'CEO',                      'thanh.vd@globallog.vn',   '0900-123-456', TRUE),
-- Tri Thức (customer 6)
(6, 'Đặng',    'Minh Tuấn', 'Hiệu trưởng',             'tuan.dm@trithuc-edu.vn',  '0911-234-567', TRUE),
(6, 'Phan',    'Thị Ngọc',  'Trưởng phòng Đào tạo',    'ngoc.pt@trithuc-edu.vn',  '0922-345-678', FALSE),
-- Sức Khỏe Vàng (customer 7)
(7, 'Hoàng',   'Thị Lan',   'Giám đốc điều hành',      'lan.ht@suckhoevang.vn',   '0903-456-789', TRUE),
(7, 'Nguyễn',  'Quốc Bảo',  'Trưởng phòng Kinh doanh', 'bao.nq@suckhoevang.vn',  '0914-567-890', FALSE),
-- Phương Đông (customer 8)
(8, 'Bùi',     'Quốc Huy',  'Giám đốc',                'huy.bq@phuongdong-tm.vn', '0925-678-901', TRUE),
(8, 'Trần',    'Minh Khoa',  'Phó phòng Kinh doanh',   'khoa.tm@phuongdong-tm.vn','0936-789-012', FALSE);

-- Interactions
INSERT INTO interactions (customer_id, contact_id, type, subject, notes, occurred_at) VALUES
-- Sao Việt
(1, 1, 'meeting', 'Họp khởi động dự án CRM',              'Thảo luận yêu cầu chi tiết, timeline 3 tháng. Khách hàng đồng ý giai đoạn 1.',                              NOW() - INTERVAL '110 days'),
(1, 2, 'email',   'Gửi tài liệu đặc tả kỹ thuật',         'Đã gửi file SRS v1.0 và wireframe cho phòng IT review.',                                                    NOW() - INTERVAL '100 days'),
(1, 1, 'call',    'Follow up tiến độ giai đoạn 1',         'Khách hàng hài lòng với tiến độ, yêu cầu bổ sung module báo cáo.',                                           NOW() - INTERVAL '75 days'),
(1, 2, 'meeting', 'Demo sản phẩm giai đoạn 1',            'Demo thành công, khách hàng duyệt nghiệm thu. Bắt đầu giai đoạn 2.',                                          NOW() - INTERVAL '50 days'),
-- Đông Á
(2, 3, 'call',    'Trao đổi nhu cầu phần mềm quản lý kho','Khách quan tâm đến giải pháp quản lý kho tích hợp ERP.',                                                     NOW() - INTERVAL '90 days'),
(2, 4, 'email',   'Gửi báo giá hệ thống quản lý kho',     'Báo giá gói Standard và Premium, hẹn họp tuần sau.',                                                          NOW() - INTERVAL '85 days'),
(2, 3, 'meeting', 'Thuyết trình giải pháp ERP',           'Trình bày demo trước ban lãnh đạo. Phó GĐ ủng hộ, đang chờ duyệt ngân sách.',                                 NOW() - INTERVAL '70 days'),
-- Hoàng Gia
(3, 5, 'call',    'Giới thiệu giải pháp quản lý sản xuất','Khách đang tìm kiếm hệ thống MES. Hẹn gặp trực tiếp tại nhà máy.',                                          NOW() - INTERVAL '55 days'),
(3, 6, 'email',   'Gửi profile công ty và case study',     'Kèm case study nhà máy ABC cùng ngành, khách phản hồi tích cực.',                                            NOW() - INTERVAL '50 days'),
(3, 5, 'meeting', 'Khảo sát nhà máy tại Đà Nẵng',        'Đánh giá quy trình hiện tại, xác định 5 điểm cải tiến. Chuẩn bị đề xuất chi tiết.',                           NOW() - INTERVAL '40 days'),
-- Thành Công
(4, 7, 'meeting', 'Họp chiến lược số hóa 2024',           'Tập đoàn muốn số hóa toàn bộ quy trình bán hàng và quản lý dự án BĐS.',                                     NOW() - INTERVAL '140 days'),
(4, 8, 'call',    'Cập nhật tiến độ triển khai',           'Module quản lý dự án đã go-live, đang training nhân viên.',                                                    NOW() - INTERVAL '90 days'),
(4, 9, 'email',   'Báo cáo hiệu quả tháng đầu tiên',      'Giảm 30% thời gian xử lý hồ sơ, tăng 20% tỷ lệ chốt sale.',                                                NOW() - INTERVAL '60 days'),
(4, 7, 'note',    'Kế hoạch mở rộng giai đoạn 2',          'Khách muốn tích hợp thêm CRM và marketing automation cho Q3.',                                               NOW() - INTERVAL '30 days'),
-- Global Logistics
(5, 10, 'call',   'Cuộc gọi giới thiệu dịch vụ',          'Liên hệ lần đầu qua giới thiệu. CEO quan tâm đến tracking hàng hóa realtime.',                               NOW() - INTERVAL '10 days'),
(5, 10, 'email',  'Gửi tài liệu giải pháp logistics',     'Kèm brochure và bảng giá. Hẹn demo online tuần tới.',                                                         NOW() - INTERVAL '5 days'),
-- Tri Thức
(6, 11, 'call',   'Tìm hiểu nhu cầu e-learning',          'Cần nền tảng LMS cho 500+ học viên. Ngân sách dự kiến 200 triệu.',                                           NOW() - INTERVAL '5 days'),
-- Sức Khỏe Vàng
(7, 13, 'meeting','Giới thiệu giải pháp HIS',             'Demo hệ thống quản lý bệnh viện. Khách muốn tùy chỉnh module khám bệnh.',                                    NOW() - INTERVAL '40 days'),
(7, 14, 'call',   'Trao đổi chi tiết kỹ thuật',           'Yêu cầu tích hợp PACS và LIS. Cần khảo sát kỹ thuật tại phòng khám.',                                        NOW() - INTERVAL '25 days'),
(7, 13, 'email',  'Gửi đề xuất và timeline triển khai',    'Đề xuất 3 giai đoạn, tổng thời gian 6 tháng. Chờ phản hồi từ ban GĐ.',                                      NOW() - INTERVAL '15 days'),
-- Phương Đông
(8, 15, 'note',   'Khách ngừng sử dụng dịch vụ',          'Hợp đồng hết hạn, khách không gia hạn do thay đổi chiến lược kinh doanh.',                                   NOW() - INTERVAL '180 days'),
(8, 15, 'call',   'Liên hệ tái kích hoạt',                'Gọi điện trao đổi về gói ưu đãi quay lại. Khách cho biết sẽ cân nhắc cuối quý.',                              NOW() - INTERVAL '30 days');
