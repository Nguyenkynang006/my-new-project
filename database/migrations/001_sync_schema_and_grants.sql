-- ============================================================
-- Migration 001 — Đồng bộ schema + quyền cho database đã khởi tạo
-- từ phiên bản cũ.
--
-- Vì sao cần: các script trong database/init/ CHỈ chạy khi volume Postgres
-- còn rỗng. Volume đã tạo từ bản cũ sẽ giữ schema/quyền cũ, dẫn tới:
--   * POST /customers -> 500 vì CHECK cũ ('prospect','active','customer','inactive')
--     không chấp nhận 'lead'/'nurturing' mà app gửi.
--   * postgres-exporter báo "permission denied for function pg_ls_waldir"
--     vì role ứng dụng chưa có pg_monitor.
--
-- Chạy MỘT LẦN trên Ubuntu (không xoá volume, không mất dữ liệu):
--
--   docker compose exec -T db sh -c \
--     'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v app_user="$CRM_APP_USER"' \
--     < database/migrations/001_sync_schema_and_grants.sql
--
-- Idempotent: chạy lại nhiều lần vẫn an toàn.
-- ============================================================
\set ON_ERROR_STOP on

-- 1) customers.status: thay CHECK cũ bằng bộ giá trị mới + map dữ liệu cũ.
ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_status_check;

UPDATE customers SET status = 'lead'   WHERE status = 'prospect';
UPDATE customers SET status = 'active' WHERE status = 'customer';

ALTER TABLE customers ADD CONSTRAINT customers_status_check
  CHECK (status IN ('lead','nurturing','active','inactive'));
ALTER TABLE customers ALTER COLUMN status SET DEFAULT 'lead';

-- 2) Cột có thể còn thiếu ở bản cũ (an toàn nếu đã có).
ALTER TABLE customers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 3) Quyền giám sát TỐI THIỂU (pg_monitor — KHÔNG phải superuser).
--    pg_ls_waldir() dùng bởi collector WAL của postgres-exporter yêu cầu role này.
GRANT pg_monitor TO :"app_user";

-- 4) Bảo đảm quyền DML/sequence của user ứng dụng (idempotent).
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"app_user";
