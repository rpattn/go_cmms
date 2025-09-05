BEGIN;

-- ------------------------------------------------------------
-- Remove task_files attachments
-- ------------------------------------------------------------
DELETE FROM task_files tf
USING tasks t
JOIN task_bases tb ON tb.id = t.task_base_id
WHERE tf.task_id = t.id
  AND tb.label IN (
    'Record gearbox oil temperature',
    'Capture transformer oil leak photo'
  );

-- ------------------------------------------------------------
-- Remove seeded tasks
-- (match by base label and WO/PM to avoid touching other data)
-- ------------------------------------------------------------
DELETE FROM tasks t
USING task_bases tb
WHERE t.task_base_id = tb.id
  AND tb.label IN (
    'Check yaw brakes',
    'Record gearbox oil temperature',
    'Verify LOTO tags applied',
    'Blade leading-edge inspection',
    'Capture transformer oil leak photo',
    'Take gearbox oil sample'
  );

-- ------------------------------------------------------------
-- Remove seeded task_options
-- ------------------------------------------------------------
DELETE FROM task_options o
USING task_bases tb
WHERE o.task_base_id = tb.id
  AND tb.label IN (
    'Check yaw brakes',
    'Verify LOTO tags applied'
  );

-- ------------------------------------------------------------
-- Remove seeded task_bases
-- ------------------------------------------------------------
DELETE FROM task_bases
WHERE label IN (
  'Check yaw brakes',
  'Record gearbox oil temperature',
  'Verify LOTO tags applied',
  'Blade leading-edge inspection',
  'Capture transformer oil leak photo',
  'Take gearbox oil sample'
);

-- ------------------------------------------------------------
-- Remove seeded meters (only demo ones)
-- ------------------------------------------------------------
DELETE FROM meters
WHERE name IN (
  'T-02 Gearbox Oil Temperature',
  'T-02 Gearbox Oil Pressure',
  'Substation Busbar Temperature'
);

COMMIT;
