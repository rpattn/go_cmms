-- name: ListWorkOrders :many
-- name: ListWorkOrders :many
SELECT
    wo.id,
    wo.organisation_id AS org_id,
    wo.title,
    wo.description,
    wo.status,
    wo.priority,
    wo.created_at,
    wo.updated_at
FROM work_order wo
WHERE wo.organisation_id = $1
ORDER BY wo.created_at DESC
LIMIT $2;

-- To call this query, use:
-- workOrders, err := db.ListWorkOrders(ctx, 10)
-- name: ListWorkOrdersPaged :many
WITH
params AS (
  SELECT $1::jsonb AS p
),
page AS (
  SELECT
    COALESCE((p->>'pageNum')::int, 0)  AS page_num,
    COALESCE((p->>'pageSize')::int,50) AS page_size
  FROM params
),
ff AS (
  SELECT jsonb_array_elements(p->'filterFields') AS f
  FROM params
  WHERE (p ? 'filterFields') AND jsonb_typeof(p->'filterFields') = 'array'
),
status_vals AS (
  SELECT COALESCE(array_agg(v), ARRAY[]::text[]) AS vals
  FROM (
    SELECT jsonb_array_elements_text(f->'values') AS v
    FROM ff
    WHERE f->>'field' = 'status' AND COALESCE(f->>'operation','') = 'in'
  ) s
),
archived_eq AS (
  SELECT (f->>'value')::boolean AS archived
  FROM ff
  WHERE f->>'field' = 'archived' AND COALESCE(f->>'operation','') IN ('eq','equals')
  LIMIT 1
),
filtered AS (
  SELECT w.*
  FROM work_order w
  LEFT JOIN status_vals sv ON TRUE
  LEFT JOIN archived_eq  a  ON TRUE
  WHERE
    (sv.vals = '{}'::text[] OR w.status = ANY (sv.vals))
    AND (a.archived IS NULL OR w.archived = a.archived)
),
-- order + count once
ordered AS (
  SELECT
    f.*,
    COUNT(*) OVER()::bigint AS total_rows,
    ROW_NUMBER() OVER (ORDER BY f.created_at DESC, f.id DESC) AS rn
  FROM filtered f
),
bounds AS (
  SELECT
    (page_num * page_size)              AS off,
    (page_num * page_size + page_size)  AS lim
  FROM page
)
SELECT
  o.*  -- includes all work_order cols + total_rows + rn
FROM ordered o
JOIN bounds b ON TRUE
WHERE o.rn > b.off AND o.rn <= b.lim
ORDER BY o.rn;
