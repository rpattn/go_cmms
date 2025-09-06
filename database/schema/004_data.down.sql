-- Down migration for WorkOrder + related tables
-- This will cleanly remove only the schema we introduced.

BEGIN;

DROP TABLE IF EXISTS work_order_counters;
DROP INDEX IF EXISTS uq_work_order_org_custom_id;
DROP TABLE IF EXISTS work_order_files;
DROP TABLE IF EXISTS work_order_customers;
DROP TABLE IF EXISTS work_order_assigned_to;
DROP INDEX IF EXISTS idx_work_order_asset;
DROP INDEX IF EXISTS idx_work_order_category;
DROP INDEX IF EXISTS idx_work_order_location;
DROP INDEX IF EXISTS idx_work_order_team;
DROP INDEX IF EXISTS idx_work_order_primary_user;
DROP INDEX IF EXISTS idx_work_order_parent_pm;
DROP INDEX IF EXISTS idx_work_order_parent_request;
DROP INDEX IF EXISTS idx_work_order_created_by;
DROP INDEX IF EXISTS idx_work_order_org;
DROP INDEX IF EXISTS idx_work_order_completed_on;
DROP INDEX IF EXISTS idx_work_order_due_date;
DROP INDEX IF EXISTS idx_work_order_archived;
DROP INDEX IF EXISTS idx_work_order_priority;
DROP INDEX IF EXISTS idx_work_order_status;
DROP TABLE IF EXISTS work_order;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS teams;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS work_order_categories;
DROP TABLE IF EXISTS preventive_maintenances;
DROP TABLE IF EXISTS requests;
DROP TABLE IF EXISTS files;

COMMIT;
-- Note: organisations and users tables are assumed to exist already.