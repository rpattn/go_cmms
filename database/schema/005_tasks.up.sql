-- Tasks / TaskBase / TaskOption migration (PostgreSQL, UUIDs via uuid-ossp)
-- Adapts:
--   - CompanyAudit -> organisation_id, created_at, updated_at, created_by_id
--   - OwnUser      -> users(id)
--   - Asset        -> assets(id)
--   - WorkOrder    -> work_order(id)
--   - PreventiveMaintenance -> preventive_maintenances(id)
-- Notes:
--   - task_type is TEXT (enum-like) with default 'SUBTASK' to stay flexible (sqlc-safe).
--   - Task.images modeled via join table task_files (keeps 'files' generic).
--   - ON DELETE behavior mirrors annotations where specified (CASCADE for WorkOrder/PM and options).

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------------
-- Minimal FK target (stub) for Meter (not present in prior migration)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- TaskBase
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS task_bases (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organisation_id   UUID REFERENCES organisations(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id     UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,

  label             TEXT NOT NULL,
  task_type         TEXT NOT NULL DEFAULT 'SUBTASK',

  user_id           UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,
  asset_id          UUID REFERENCES assets(id) ON UPDATE CASCADE ON DELETE SET NULL,
  meter_id          UUID REFERENCES meters(id) ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_task_bases_org         ON task_bases (organisation_id);
CREATE INDEX IF NOT EXISTS idx_task_bases_user        ON task_bases (user_id);
CREATE INDEX IF NOT EXISTS idx_task_bases_asset       ON task_bases (asset_id);
CREATE INDEX IF NOT EXISTS idx_task_bases_meter       ON task_bases (meter_id);
CREATE INDEX IF NOT EXISTS idx_task_bases_task_type   ON task_bases (task_type);

-- ---------------------------------------------------------------------------
-- TaskOption (belongs to TaskBase; cascades on delete of TaskBase, per orphanRemoval)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS task_options (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organisation_id   UUID REFERENCES organisations(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id     UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,

  label             TEXT,
  task_base_id      UUID NOT NULL REFERENCES task_bases(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_task_options_task_base ON task_options (task_base_id);
-- If you want to prevent duplicate option labels per TaskBase, uncomment:
-- CREATE UNIQUE INDEX IF NOT EXISTS uq_task_options_base_label ON task_options (task_base_id, label) WHERE label IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Tasks (concrete instances bound to a TaskBase; optionally linked to WorkOrder or PM)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tasks (
  id                           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organisation_id              UUID REFERENCES organisations(id) ON UPDATE CASCADE ON DELETE SET NULL,
  created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id                UUID REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL,

  task_base_id                 UUID NOT NULL REFERENCES task_bases(id) ON UPDATE CASCADE,  -- NO ACTION/RESTRICT on delete
  notes                        TEXT,
  value                        TEXT,

  work_order_id                UUID REFERENCES work_order(id) ON UPDATE CASCADE ON DELETE CASCADE,
  preventive_maintenance_id    UUID REFERENCES preventive_maintenances(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_tasks_org                    ON tasks (organisation_id);
CREATE INDEX IF NOT EXISTS idx_tasks_task_base              ON tasks (task_base_id);
CREATE INDEX IF NOT EXISTS idx_tasks_work_order             ON tasks (work_order_id);
CREATE INDEX IF NOT EXISTS idx_tasks_preventive_maint       ON tasks (preventive_maintenance_id);
CREATE INDEX IF NOT EXISTS idx_tasks_created_by             ON tasks (created_by_id);

-- Optional: if you want to require a parent (either WorkOrder or PM), uncomment:
-- ALTER TABLE tasks ADD CONSTRAINT chk_tasks_parent_present
--   CHECK (work_order_id IS NOT NULL OR preventive_maintenance_id IS NOT NULL);

-- ---------------------------------------------------------------------------
-- Task <-> Files (images) link table
-- Mirrors @OneToMany(mappedBy="task") by keeping files generic and attachable.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS task_files (
  task_id  UUID NOT NULL REFERENCES tasks(id)  ON UPDATE CASCADE ON DELETE CASCADE,
  file_id  UUID NOT NULL REFERENCES files(id)  ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (task_id, file_id)
);

CREATE INDEX IF NOT EXISTS idx_task_files_file ON task_files (file_id);

COMMIT;

-- ---------------------------------------------------------------------------
-- Down migration (drop in reverse dependency order)
-- ---------------------------------------------------------------------------
-- BEGIN;
-- DROP TABLE IF EXISTS task_files;
-- DROP INDEX IF EXISTS idx_tasks_created_by;
-- DROP INDEX IF EXISTS idx_tasks_preventive_maint;
-- DROP INDEX IF EXISTS idx_tasks_work_order;
-- DROP INDEX IF EXISTS idx_tasks_task_base;
-- DROP INDEX IF EXISTS idx_tasks_org;
-- DROP TABLE IF EXISTS tasks;
-- DROP INDEX IF EXISTS idx_task_options_task_base;
-- DROP TABLE IF EXISTS task_options;
-- DROP INDEX IF EXISTS idx_task_bases_task_type;
-- DROP INDEX IF EXISTS idx_task_bases_meter;
-- DROP INDEX IF EXISTS idx_task_bases_asset;
-- DROP INDEX IF EXISTS idx_task_bases_user;
-- DROP INDEX IF EXISTS idx_task_bases_org;
-- DROP TABLE IF EXISTS task_bases;
-- -- Only drop meters if this migration introduced it and nothing else depends on it:
-- -- DROP TABLE IF EXISTS meters;
-- COMMIT;
