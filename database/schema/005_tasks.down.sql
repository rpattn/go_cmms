---------------------------------------------------------------------------
-- Down migration (drop in reverse dependency order)
---------------------------------------------------------------------------
BEGIN;
DROP TABLE IF EXISTS task_files;
DROP INDEX IF EXISTS idx_tasks_created_by;
DROP INDEX IF EXISTS idx_tasks_preventive_maint;
DROP INDEX IF EXISTS idx_tasks_work_order;
DROP INDEX IF EXISTS idx_tasks_task_base;
DROP INDEX IF EXISTS idx_tasks_org;
DROP TABLE IF EXISTS tasks;
DROP INDEX IF EXISTS idx_task_options_task_base;
DROP TABLE IF EXISTS task_options;
DROP INDEX IF EXISTS idx_task_bases_task_type;
DROP INDEX IF EXISTS idx_task_bases_meter;
DROP INDEX IF EXISTS idx_task_bases_asset;
DROP INDEX IF EXISTS idx_task_bases_user;
DROP INDEX IF EXISTS idx_task_bases_org;
DROP TABLE IF EXISTS task_bases;
-- Only drop meters if this migration introduced it and nothing else depends on it:
DROP TABLE IF EXISTS meters;
COMMIT;
