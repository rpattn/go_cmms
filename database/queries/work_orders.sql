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