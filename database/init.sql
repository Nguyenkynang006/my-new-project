-- ============================================================
-- CRM Customer Care System — Database Schema
-- Hệ thống CRM Chăm sóc Khách hàng
-- ============================================================

-- Custom enum types
DO $$ BEGIN
    CREATE TYPE customer_status AS ENUM ('lead', 'nurturing', 'active', 'inactive');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE interaction_type AS ENUM ('call', 'email', 'meeting', 'note');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- Customers — tổ chức/cá nhân được CRM quản lý
-- ============================================================
CREATE TABLE IF NOT EXISTS customers (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(255)      NOT NULL,
    company_name  VARCHAR(255),
    industry      VARCHAR(100),
    email         VARCHAR(255),
    phone         VARCHAR(50),
    address       TEXT,
    status        customer_status   NOT NULL DEFAULT 'lead',
    deleted_at    TIMESTAMPTZ       DEFAULT NULL,
    created_at    TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Contacts — người liên hệ thuộc khách hàng
-- ============================================================
CREATE TABLE IF NOT EXISTS contacts (
    id            SERIAL PRIMARY KEY,
    customer_id   INTEGER           NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    first_name    VARCHAR(100)      NOT NULL,
    last_name     VARCHAR(100)      NOT NULL,
    job_title     VARCHAR(100),
    email         VARCHAR(255),
    phone         VARCHAR(50),
    is_primary    BOOLEAN           NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Interactions — lịch sử tương tác / chăm sóc
-- ============================================================
CREATE TABLE IF NOT EXISTS interactions (
    id            SERIAL PRIMARY KEY,
    customer_id   INTEGER           NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    contact_id    INTEGER           REFERENCES contacts(id) ON DELETE SET NULL,
    type          interaction_type  NOT NULL,
    subject       VARCHAR(255)      NOT NULL,
    notes         TEXT,
    occurred_at   TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    created_at    TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_customers_status      ON customers(status);
CREATE INDEX IF NOT EXISTS idx_customers_deleted_at   ON customers(deleted_at);
CREATE INDEX IF NOT EXISTS idx_customers_name         ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_company      ON customers(company_name);
CREATE INDEX IF NOT EXISTS idx_contacts_customer_id   ON contacts(customer_id);
CREATE INDEX IF NOT EXISTS idx_interactions_customer   ON interactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_interactions_contact    ON interactions(contact_id);
CREATE INDEX IF NOT EXISTS idx_interactions_occurred   ON interactions(occurred_at DESC);

-- ============================================================
-- Auto-update updated_at on customers
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_customers_updated_at ON customers;
CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
