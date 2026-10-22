CREATE TABLE customers (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  company_name VARCHAR(200),
  email VARCHAR(254),
  phone VARCHAR(40),
  status VARCHAR(20) NOT NULL DEFAULT 'prospect' CHECK (status IN ('prospect','active','customer','inactive')),
  industry VARCHAR(120),
  address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE contacts (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL DEFAULT '',
  job_title VARCHAR(120), email VARCHAR(254), phone VARCHAR(40),
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX contacts_one_primary_per_customer ON contacts(customer_id) WHERE is_primary;
ALTER TABLE contacts ADD CONSTRAINT contacts_id_customer_unique UNIQUE (id, customer_id);
CREATE TABLE interactions (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  contact_id BIGINT,
  type VARCHAR(20) NOT NULL CHECK (type IN ('call','email','meeting','note')),
  subject VARCHAR(200) NOT NULL,
  notes TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE interactions ADD CONSTRAINT interactions_contact_customer_fk
  FOREIGN KEY (contact_id, customer_id) REFERENCES contacts(id, customer_id)
  ON DELETE SET NULL (contact_id);
CREATE INDEX contacts_customer_idx ON contacts(customer_id);
CREATE INDEX interactions_customer_time_idx ON interactions(customer_id, occurred_at DESC);
