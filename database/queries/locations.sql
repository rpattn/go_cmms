-- Search locations used within an organisation with filter + paging
-- name: SearchOrgLocations :many
WITH input AS (
  SELECT
    sqlc.arg(org_id)::uuid   AS org_id,
    sqlc.arg(payload)::jsonb AS payload
),
params AS (
  SELECT
    org_id,
    GREATEST(1, LEAST(COALESCE((payload->>'pageSize')::int, 10), 100)) AS page_size,
    GREATEST(0, COALESCE((payload->>'pageNum')::int, 0))                AS page_num,
    COALESCE(payload->'filterFields', '[]'::jsonb)                      AS filters
  FROM input
),
base AS (
  SELECT DISTINCT l.id, l.name, l.created_at
  FROM locations l
  JOIN work_order w ON w.location_id = l.id
  WHERE w.organisation_id = (SELECT org_id FROM params)
),
filtered AS (
  SELECT
    b.*,
    COUNT(*) OVER () AS total_count
  FROM base b
  LEFT JOIN LATERAL (
    SELECT
      grp_idx,
      BOOL_OR(
        CASE col
          WHEN 'name' THEN
            CASE op
              WHEN 'eq' THEN b.name = val
              WHEN 'cn' THEN b.name ILIKE '%' || val || '%'
              WHEN 'sw' THEN b.name ILIKE val || '%'
              WHEN 'ew' THEN b.name ILIKE '%' || val
              ELSE b.name = val
            END
          ELSE FALSE
        END
      ) AS group_match,
      BOOL_OR(col IS NOT NULL) AS has_recognized
    FROM (
      SELECT ROW_NUMBER() OVER () AS grp_idx, g.elem
      FROM params p,
           LATERAL jsonb_array_elements(p.filters) AS g(elem)
    ) grp
    CROSS JOIN LATERAL (
      SELECT
        CASE LOWER(COALESCE(grp.elem->>'field',''))
          WHEN 'name' THEN 'name'
          ELSE NULL
        END                                    AS col,
        LOWER(COALESCE(grp.elem->>'operation','eq')) AS op,
        COALESCE(grp.elem->>'value','')        AS val
      UNION ALL
      SELECT
        CASE LOWER(COALESCE(alt->>'field',''))
          WHEN 'name' THEN 'name'
          ELSE NULL
        END,
        LOWER(COALESCE(alt->>'operation','eq')),
        COALESCE(alt->>'value','')
      FROM jsonb_array_elements(COALESCE(grp.elem->'alternatives','[]'::jsonb)) alt
    ) c
    GROUP BY grp_idx
  ) g ON TRUE
  GROUP BY b.id, b.name, b.created_at
  HAVING COALESCE(BOOL_AND((NOT g.has_recognized) OR g.group_match), TRUE)
)
SELECT
  id::uuid       AS id,
  name::text     AS name,
  created_at     AS created_at,
  total_count    AS total_count
FROM filtered
ORDER BY created_at DESC
LIMIT (SELECT page_size FROM params)
OFFSET (SELECT page_size * page_num FROM params);

