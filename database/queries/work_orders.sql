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
/* generic text search (title + description) */
text_cn AS (
  SELECT NULLIF(btrim(f->>'value'), '') AS term
  FROM ff
  WHERE f->>'field' = 'text' AND COALESCE(f->>'operation','') IN ('cn','contains','like')
  LIMIT 1
),
/* NEW: sort options (whitelisted later) */
sort AS (
  SELECT
    lower(NULLIF(p->>'sortField',''))     AS field,
    upper(COALESCE(NULLIF(p->>'direction',''),'DESC')) AS dir
  FROM params
),
filtered AS (
  SELECT w.*
  FROM work_order w
  LEFT JOIN status_vals sv ON TRUE
  LEFT JOIN archived_eq  a  ON TRUE
  LEFT JOIN text_cn      t  ON TRUE
  WHERE
    (sv.vals = '{}'::text[] OR w.status = ANY (sv.vals))
    AND (a.archived IS NULL OR w.archived = a.archived)
    AND (
      t.term IS NULL
      OR (
        w.title ILIKE (
          '%' ||
          replace(replace(replace(t.term, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_')
          || '%'
        ) ESCAPE E'\\'
        OR w.description ILIKE (
          '%' ||
          replace(replace(replace(t.term, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_')
          || '%'
        ) ESCAPE E'\\'
      )
    )
),
ordered AS (
  SELECT
    f.*,
    COUNT(*) OVER()::bigint AS total_rows,
    ROW_NUMBER() OVER (
      ORDER BY
        /* ASC cases */
        CASE WHEN s.field='custom_id'  AND s.dir='ASC'  THEN f.custom_id  END ASC  NULLS LAST,
        CASE WHEN s.field='due_date'   AND s.dir='ASC'  THEN f.due_date   END ASC  NULLS LAST,
        CASE WHEN s.field='created_at' AND s.dir='ASC'  THEN f.created_at END ASC  NULLS LAST,
        CASE WHEN s.field='priority'   AND s.dir='ASC'  THEN f.priority   END ASC  NULLS LAST,
        CASE WHEN s.field='status'     AND s.dir='ASC'  THEN f.status     END ASC  NULLS LAST,
        CASE WHEN s.field='title'      AND s.dir='ASC'  THEN f.title      END ASC  NULLS LAST,

        /* DESC cases */
        CASE WHEN s.field='custom_id'  AND s.dir='DESC' THEN f.custom_id  END DESC NULLS LAST,
        CASE WHEN s.field='due_date'   AND s.dir='DESC' THEN f.due_date   END DESC NULLS LAST,
        CASE WHEN s.field='created_at' AND s.dir='DESC' THEN f.created_at END DESC NULLS LAST,
        CASE WHEN s.field='priority'   AND s.dir='DESC' THEN f.priority   END DESC NULLS LAST,
        CASE WHEN s.field='status'     AND s.dir='DESC' THEN f.status     END DESC NULLS LAST,
        CASE WHEN s.field='title'      AND s.dir='DESC' THEN f.title      END DESC NULLS LAST,

        /* deterministic fallback when no sort provided or ties */
        f.created_at DESC, f.id DESC
    ) AS rn
  FROM filtered f
  CROSS JOIN sort s
),
page_bounds AS (
  SELECT
    (page_num * page_size)             AS off,
    (page_num * page_size + page_size) AS lim
  FROM page
)
SELECT
  o.*
FROM ordered o
JOIN page_bounds b ON TRUE
WHERE o.rn > b.off AND o.rn <= b.lim
ORDER BY o.rn;
