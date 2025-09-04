-- name: UpsertUserByVerifiedEmail :one
INSERT INTO users (email, name)
VALUES ($1, $2)
ON CONFLICT (email)
DO UPDATE SET name = COALESCE(users.name, EXCLUDED.name)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;

-- params: $1 = user_id (UUID), $2 = org_id (UUID)
-- name: GetUserWithOrgAndRole :one
WITH
  input AS (
    SELECT $1::uuid AS user_id, $2::uuid AS org_id
  ),
  u AS (
    SELECT u.id, u.email, u.name, u.created_at
    FROM users u
    JOIN input i ON u.id = i.user_id
  ),
  o AS (
    SELECT o.id, o.slug, o.name, o.created_at
    FROM organisations o
    JOIN input i ON o.id = i.org_id
  ),
  m AS (
    SELECT om.org_id, om.user_id, om.role
    FROM org_memberships om
    JOIN o ON om.org_id = o.id
    JOIN u ON om.user_id = u.id
  )
SELECT
  u.id            AS user_id,
  u.email         AS user_email,
  u.name          AS user_name,
  o.id            AS org_id,
  o.slug          AS org_slug,
  o.name          AS org_name,
  m.role::text    AS role,
  (u.id IS NOT NULL)::bool AS user_exists,
  (o.id IS NOT NULL)::bool AS org_exists,
  (m.role IS NOT NULL)::bool AS role_exists
FROM input i
LEFT JOIN u ON TRUE
LEFT JOIN o ON TRUE
LEFT JOIN m ON TRUE
LIMIT 1;

