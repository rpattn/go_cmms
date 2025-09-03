-- name: EnsureMembership :one
INSERT INTO org_memberships (org_id, user_id, role)
VALUES (@org_id, @user_id, @role)
ON CONFLICT (org_id, user_id)
DO UPDATE SET role = EXCLUDED.role
RETURNING role::text AS role;

-- name: GetRole :one
SELECT role::text AS role
FROM org_memberships
WHERE org_id = $1 AND user_id = $2;

-- name: UpdateRole :exec
UPDATE org_memberships
SET role = $3
WHERE org_id = $1 AND user_id = $2;

-- name: PickUserOrg :one
SELECT o.*
FROM org_memberships m
JOIN organisations o ON o.id = m.org_id
WHERE m.user_id = $1
ORDER BY m.role DESC, o.created_at ASC
LIMIT 1;
