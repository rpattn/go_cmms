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
        CASE WHEN s.field='updated_at' AND s.dir='ASC'  THEN f.updated_at END ASC  NULLS LAST,
        CASE WHEN s.field='priority'   AND s.dir='ASC'  THEN f.priority   END ASC  NULLS LAST,
        CASE WHEN s.field='status'     AND s.dir='ASC'  THEN f.status     END ASC  NULLS LAST,
        CASE WHEN s.field='title'      AND s.dir='ASC'  THEN f.title      END ASC  NULLS LAST,

        /* DESC cases */
        CASE WHEN s.field='custom_id'  AND s.dir='DESC' THEN f.custom_id  END DESC NULLS LAST,
        CASE WHEN s.field='due_date'   AND s.dir='DESC' THEN f.due_date   END DESC NULLS LAST,
        CASE WHEN s.field='created_at' AND s.dir='DESC' THEN f.created_at END DESC NULLS LAST,
        CASE WHEN s.field='updated_at' AND s.dir='DESC' THEN f.updated_at END DESC NULLS LAST,
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



-- name: GetWorkOrderDetail :one
SELECT
  jsonb_strip_nulls(
    jsonb_build_object(
      'id',                       wo.id,
      'organisation_id',          wo.organisation_id,
      'created_at',               wo.created_at,
      'updated_at',               wo.updated_at,
      'created_by_id',            wo.created_by_id,
      'due_date',                 wo.due_date,
      'priority',                 wo.priority,
      'estimated_duration',       wo.estimated_duration,
      'estimated_start_date',     wo.estimated_start_date,
      'description',              wo.description,
      'title',                    wo.title,
      'required_signature',       wo.required_signature,
      'custom_id',                wo.custom_id,
      'completed_by_id',          wo.completed_by_id,
      'completed_on',             wo.completed_on,
      'status',                   wo.status,
      'archived',                 wo.archived,
      'feedback',                 wo.feedback,
      'first_time_to_react',      wo.first_time_to_react,

      -- NEW: primary worker (object with id + name)
      'primary_worker', (
        SELECT jsonb_build_object(
          'id', u.id,
          'name', u.name,
          'email', u.email
        )
        FROM users u
        WHERE u.id = wo.primary_user_id
      ),

      'image',                    (SELECT jsonb_build_object('id', fimg.id, 'filename', fimg.filename, 'path', fimg.path, 'created_at', fimg.created_at)
                                   FROM files fimg WHERE fimg.id = wo.image_id),
      'signature',                (SELECT jsonb_build_object('id', fsig.id, 'filename', fsig.filename, 'path', fsig.path, 'created_at', fsig.created_at)
                                   FROM files fsig WHERE fsig.id = wo.signature_id),
      'category',                 (SELECT jsonb_build_object('id', c.id, 'name', c.name, 'created_at', c.created_at)
                                   FROM work_order_categories c WHERE c.id = wo.category_id),
      'location',                 (SELECT jsonb_build_object('id', l.id, 'name', l.name, 'created_at', l.created_at)
                                   FROM locations l WHERE l.id = wo.location_id),
      'team',                     (SELECT jsonb_build_object('id', t.id, 'name', t.name, 'created_at', t.created_at)
                                   FROM teams t WHERE t.id = wo.team_id),
      'asset',                    (SELECT jsonb_build_object('id', a.id, 'name', a.name, 'created_at', a.created_at)
                                   FROM assets a WHERE a.id = wo.asset_id),
      'parent_request',           (SELECT jsonb_build_object('id', r.id, 'title', r.title, 'created_at', r.created_at)
                                   FROM requests r WHERE r.id = wo.parent_request_id),
      'parent_preventive_maint',  (SELECT jsonb_build_object('id', pm.id, 'name', pm.name, 'created_at', pm.created_at)
                                   FROM preventive_maintenances pm WHERE pm.id = wo.parent_preventive_maint_id),

      'assigned_to',              COALESCE(
                                     (
                                       SELECT jsonb_agg(
                                         jsonb_build_object(
                                           'user_id', x.user_id,
                                           'name',    u.name,
                                           'email',   u.email
                                         )
                                       )
                                       FROM work_order_assigned_to x
                                       JOIN users u ON u.id = x.user_id
                                       WHERE x.work_order_id = wo.id
                                     ),
                                     '[]'::jsonb
                                   ),

      'customers',                COALESCE(
                                     (SELECT jsonb_agg(jsonb_build_object('id', c2.id, 'name', c2.name, 'email', c2.email, 'created_at', c2.created_at))
                                      FROM work_order_customers woc2
                                      JOIN customers c2 ON c2.id = woc2.customer_id
                                      WHERE woc2.work_order_id = wo.id),
                                     '[]'::jsonb
                                   ),

      'files',                    COALESCE(
                                     (SELECT jsonb_agg(jsonb_build_object('id', f.id, 'filename', f.filename, 'path', f.path, 'created_at', f.created_at))
                                      FROM work_order_files wf
                                      JOIN files f ON f.id = wf.file_id
                                      WHERE wf.work_order_id = wo.id),
                                     '[]'::jsonb
                                   )
    )
  ) AS work_order
FROM work_order wo
WHERE wo.id = $1::uuid
LIMIT 1;
-- ---------------------------------------------------------------------------

-- name: ChangeWorkOrderStatus :exec
UPDATE work_order
SET
  status = @status,
  completed_on = CASE WHEN upper(@status) = 'COMPLETE'
                      THEN COALESCE(completed_on, now())
                      ELSE NULL
                 END,
  updated_at = now()
WHERE id = @work_order_id
  AND organisation_id = @organisation_id;


-- name: CreateWorkOrderFromJSON :one
SELECT create_work_order_from_json(
  @organisation_id::uuid,
  @created_by_id::uuid,
  @payload::jsonb
)::uuid AS id;

-- name: UpdateWorkOrderFromJSON :one
SELECT public.update_work_order_from_json(
  @organisation_id::uuid,
  @work_order_id::uuid,
  @payload::jsonb,
  @updated_by_id::uuid
)::uuid AS id;
