-- WorkOrder + WorkOrderBase migration (PostgreSQL, UUIDs via uuid-ossp)

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------------
-- Minimal FK target tables (stubs; expand as your app requires)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS files (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  path TEXT,
  filename TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS preventive_maintenances (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS work_order_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- WorkOrder
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS work_order (
  id                           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organisation_id              UUID REFERENCES organisations(id) ON UPDATE CASCADE ON DELETE SET NULL,

  created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id                UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,

  due_date                     TIMESTAMPTZ,
  priority                     TEXT NOT NULL DEFAULT 'NONE',
  estimated_duration           DOUBLE PRECISION NOT NULL DEFAULT 0,
  estimated_start_date         TIMESTAMPTZ,
  description                  VARCHAR(10000),
  title                        TEXT NOT NULL,
  required_signature           BOOLEAN NOT NULL DEFAULT FALSE,
  image_id                     UUID REFERENCES files(id) ON UPDATE CASCADE ON DELETE SET NULL,
  category_id                  UUID REFERENCES work_order_categories(id) ON UPDATE CASCADE ON DELETE SET NULL,
  location_id                  UUID REFERENCES locations(id) ON UPDATE CASCADE ON DELETE SET NULL,
  team_id                      UUID REFERENCES teams(id) ON UPDATE CASCADE ON DELETE SET NULL,
  primary_user_id              UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,
  asset_id                     UUID REFERENCES assets(id) ON UPDATE CASCADE ON DELETE SET NULL,

  custom_id                    TEXT,
  completed_by_id              UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,
  completed_on                 TIMESTAMPTZ,
  status                       TEXT NOT NULL DEFAULT 'OPEN',
  signature_id                 UUID REFERENCES files(id) ON UPDATE CASCADE ON DELETE SET NULL,
  archived                     BOOLEAN NOT NULL DEFAULT FALSE,
  parent_request_id            UUID REFERENCES requests(id) ON UPDATE CASCADE ON DELETE SET NULL,
  feedback                     TEXT,
  parent_preventive_maint_id   UUID REFERENCES preventive_maintenances(id) ON UPDATE CASCADE ON DELETE SET NULL,
  first_time_to_react          TIMESTAMPTZ
);

-- ✅ Make custom_id unique within an organisation (used by your generator)
CREATE UNIQUE INDEX IF NOT EXISTS uq_work_order_org_custom_id
  ON work_order (organisation_id, custom_id)
  WHERE custom_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Many-to-many relations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS work_order_assigned_to (
  work_order_id  UUID NOT NULL REFERENCES work_order(id) ON UPDATE CASCADE ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES users(id)      ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (work_order_id, user_id)
);

CREATE TABLE IF NOT EXISTS work_order_customers (
  work_order_id  UUID NOT NULL REFERENCES work_order(id) ON UPDATE CASCADE ON DELETE CASCADE,
  customer_id    UUID NOT NULL REFERENCES customers(id)  ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (work_order_id, customer_id)
);

CREATE TABLE IF NOT EXISTS work_order_files (
  work_order_id  UUID NOT NULL REFERENCES work_order(id) ON UPDATE CASCADE ON DELETE CASCADE,
  file_id        UUID NOT NULL REFERENCES files(id)      ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (work_order_id, file_id)
);

-- ---------------------------------------------------------------------------
-- Helpful indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_work_order_status            ON work_order (status);
CREATE INDEX IF NOT EXISTS idx_work_order_priority          ON work_order (priority);
CREATE INDEX IF NOT EXISTS idx_work_order_archived          ON work_order (archived);
CREATE INDEX IF NOT EXISTS idx_work_order_due_date          ON work_order (due_date);
CREATE INDEX IF NOT EXISTS idx_work_order_completed_on      ON work_order (completed_on);
CREATE INDEX IF NOT EXISTS idx_work_order_org               ON work_order (organisation_id);
CREATE INDEX IF NOT EXISTS idx_work_order_created_by        ON work_order (created_by_id);
CREATE INDEX IF NOT EXISTS idx_work_order_parent_request    ON work_order (parent_request_id);
CREATE INDEX IF NOT EXISTS idx_work_order_parent_pm         ON work_order (parent_preventive_maint_id);
CREATE INDEX IF NOT EXISTS idx_work_order_primary_user      ON work_order (primary_user_id);
CREATE INDEX IF NOT EXISTS idx_work_order_team              ON work_order (team_id);
CREATE INDEX IF NOT EXISTS idx_work_order_location          ON work_order (location_id);
CREATE INDEX IF NOT EXISTS idx_work_order_category          ON work_order (category_id);
CREATE INDEX IF NOT EXISTS idx_work_order_asset             ON work_order (asset_id);

-- ---------------------------------------------------------------------------
-- 🚀 Per-org, per-year counter table for custom_id generation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS work_order_counters (
  organisation_id UUID NOT NULL,
  year            INTEGER NOT NULL,
  next_seq        INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (organisation_id, year)
);

-- Safety net unique index
CREATE UNIQUE INDEX IF NOT EXISTS uq_work_order_org_custom_id
  ON work_order (organisation_id, custom_id)
  WHERE custom_id IS NOT NULL;

-- Backfill counters from existing custom_id values like 'WO-YYYY-NNNN'
WITH wo AS (
  SELECT
    organisation_id,
    split_part(custom_id,'-',2)::int AS year,
    split_part(custom_id,'-',3)::int AS seq
  FROM work_order
  WHERE custom_id ~ '^WO-\d{4}-\d{4}$'
)
INSERT INTO work_order_counters (organisation_id, year, next_seq)
SELECT organisation_id, year, MAX(seq) + 1
FROM wo
GROUP BY organisation_id, year
ON CONFLICT (organisation_id, year)
DO UPDATE
SET next_seq = GREATEST(work_order_counters.next_seq, EXCLUDED.next_seq);

COMMIT;

-- ---------------------------------------------------------------------------
-- Down migration (drop in reverse dependency order)
-- ---------------------------------------------------------------------------
-- BEGIN;
-- DROP TABLE IF EXISTS work_order_counters;
-- DROP INDEX IF EXISTS uq_work_order_org_custom_id;
-- DROP TABLE IF EXISTS work_order_files;
-- DROP TABLE IF EXISTS work_order_customers;
-- DROP TABLE IF EXISTS work_order_assigned_to;
-- DROP INDEX IF EXISTS idx_work_order_asset;
-- DROP INDEX IF EXISTS idx_work_order_category;
-- DROP INDEX IF EXISTS idx_work_order_location;
-- DROP INDEX IF EXISTS idx_work_order_team;
-- DROP INDEX IF EXISTS idx_work_order_primary_user;
-- DROP INDEX IF EXISTS idx_work_order_parent_pm;
-- DROP INDEX IF EXISTS idx_work_order_parent_request;
-- DROP INDEX IF EXISTS idx_work_order_created_by;
-- DROP INDEX IF EXISTS idx_work_order_org;
-- DROP INDEX IF EXISTS idx_work_order_completed_on;
-- DROP INDEX IF EXISTS idx_work_order_due_date;
-- DROP INDEX IF EXISTS idx_work_order_archived;
-- DROP INDEX IF EXISTS idx_work_order_priority;
-- DROP INDEX IF EXISTS idx_work_order_status;
-- DROP TABLE IF EXISTS work_order;
-- DROP TABLE IF EXISTS assets;
-- DROP TABLE IF EXISTS customers;
-- DROP TABLE IF EXISTS teams;
-- DROP TABLE IF EXISTS locations;
-- DROP TABLE IF EXISTS work_order_categories;
-- DROP TABLE IF EXISTS preventive_maintenances;
-- DROP TABLE IF EXISTS requests;
-- DROP TABLE IF EXISTS files;
-- COMMIT;
