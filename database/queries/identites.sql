-- name: LinkIdentity :exec
INSERT INTO identities (user_id, provider, subject)
VALUES ($1, $2, $3)
ON CONFLICT (provider, subject)
DO NOTHING;

-- name: GetUserByIdentity :one
SELECT u.*
FROM identities i
JOIN users u ON u.id = i.user_id
WHERE i.provider = $1 AND i.subject = $2;
