-- Down migration for WorkOrder + related tables
-- This will cleanly remove only the schema we introduced.

BEGIN;

-- Drop many-to-many join tables first
DROP TABLE IF EXISTS work_order_files;
DROP TABLE IF EXISTS work_order_customers;
DROP TABLE IF EXISTS work_order_assigned_to;

-- Drop indexes (if your migration tool doesn't auto-drop with table drops)
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

-- Drop main work_order table
DROP TABLE IF EXISTS work_order;

-- Drop minimal FK target tables we created
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS teams;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS work_order_categories;
DROP TABLE IF EXISTS preventive_maintenances;
DROP TABLE IF EXISTS requests;
DROP TABLE IF EXISTS files;

-- DO NOT drop `users` or `organisations` because those already exist in your system.

COMMIT;
-- Note: organisations and users tables are assumed to exist already.