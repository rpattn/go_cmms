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
