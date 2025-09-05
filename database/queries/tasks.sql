-- name: GetTasksByWorkOrderID :many
SELECT
  t.id                        AS task_id,
  t.organisation_id           AS task_org_id,
  t.created_at                AS task_created_at,
  t.updated_at                AS task_updated_at,
  t.created_by_id             AS task_created_by_id,
  t.notes                     AS task_notes,
  t.value                     AS task_value,
  t.work_order_id             AS task_work_order_id,
  t.preventive_maintenance_id AS task_preventive_maintenance_id,

  -- TaskBase
  tb.id                       AS task_base_id,
  tb.label                    AS task_base_label,
  tb.task_type                AS task_base_type,

  -- Linked User
  u.id                        AS task_user_id,
  u.name                      AS task_user_name,
  u.email                     AS task_user_email,

  -- Asset
  a.id                        AS task_asset_id,
  a.name                      AS task_asset_name,

  -- Meter
  m.id                        AS task_meter_id,
  m.name                      AS task_meter_name,

  -- PreventiveMaintenance
  pm.id                       AS pm_id,
  pm.name                     AS pm_name,

  -- WorkOrder
  wo.id                       AS work_order_id,
  wo.title                    AS work_order_title,
  wo.status                   AS work_order_status,

  -- Options (aggregated as JSON array)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'id', topt.id,
        'label', topt.label
      )
    ) FILTER (WHERE topt.id IS NOT NULL),
    '[]'
  )                           AS task_options,

  -- Files (aggregated as JSON array)
  COALESCE(
    json_agg(
      DISTINCT jsonb_build_object(
        'id', f.id,
        'filename', f.filename,
        'path', f.path
      )
    ) FILTER (WHERE f.id IS NOT NULL),
    '[]'
  )                           AS task_files

FROM tasks t
JOIN task_bases tb ON tb.id = t.task_base_id
LEFT JOIN users u ON u.id = tb.user_id
LEFT JOIN assets a ON a.id = tb.asset_id
LEFT JOIN meters m ON m.id = tb.meter_id
LEFT JOIN preventive_maintenances pm ON pm.id = t.preventive_maintenance_id
JOIN work_order wo ON wo.id = t.work_order_id AND wo.organisation_id = $1
LEFT JOIN task_options topt ON topt.task_base_id = tb.id
LEFT JOIN task_files tf ON tf.task_id = t.id
LEFT JOIN files f ON f.id = tf.file_id

WHERE t.work_order_id = $2
  AND t.organisation_id = $1

GROUP BY
  t.id, tb.id, u.id, a.id, m.id, pm.id, wo.id;


-- name: ListSimpleTasksByWorkOrder :many
SELECT
  t.id AS id,                                                -- UUID
  tb.label AS title,                                         -- task "title"
  (UPPER(COALESCE(t.value, '')) IN ('COMPLETE','PASS')) AS completed,
  u.name AS assignee_name,
  jsonb_build_object(                                        -- taskBase payload
    'id', tb.id,
    'label', tb.label,
    'taskType', tb.task_type,
    'assetId', tb.asset_id,
    'meterId', tb.meter_id
  ) AS task_base
FROM tasks t
JOIN task_bases tb ON tb.id = t.task_base_id
LEFT JOIN users u ON u.id = tb.user_id
JOIN work_order wo ON wo.id = t.work_order_id AND wo.organisation_id = $1
WHERE t.organisation_id = $1
  AND t.work_order_id   = $2
ORDER BY t.created_at ASC;


-- name: MarkTaskComplete :one
UPDATE tasks
SET
  value = 'COMPLETE',
  updated_at = now()
WHERE organisation_id = $1
  AND id = $2
RETURNING
  id,
  organisation_id,
  value,
  updated_at;


-- name: DeleteTaskByID :exec
DELETE FROM tasks
WHERE organisation_id = $1
  AND id = $2;

-- name: ToggleTaskCompletion :one
UPDATE tasks
SET
  value = CASE
    WHEN @complete::boolean = true
      THEN 'COMPLETE'
    WHEN @complete::boolean = false AND previous_value IS NOT NULL
      THEN previous_value
    WHEN @complete::boolean = false
      THEN 'OPEN'
    ELSE value
  END,
  previous_value = CASE
    WHEN @complete::boolean = true
      THEN value  -- stash current before marking complete
    ELSE previous_value
  END,
  updated_at = now()
WHERE organisation_id = @organisation_id
  AND id = @id
RETURNING
  id,
  organisation_id,
  value,
  previous_value,
  updated_at;

