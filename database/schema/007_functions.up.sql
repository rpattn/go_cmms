CREATE OR REPLACE FUNCTION public.create_work_order_from_json(
  org_id     UUID,
  created_by UUID,
  payload    JSONB
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_id UUID;

  -- core fields
  v_title       TEXT;
  v_priority    TEXT;
  v_description TEXT;

  -- dates
  v_due_text       TEXT;
  v_est_start_text TEXT;
  v_due_date       TIMESTAMPTZ;
  v_est_start      TIMESTAMPTZ;

  -- numerics / booleans
  v_est_duration       DOUBLE PRECISION;
  v_required_signature BOOLEAN;

  -- fks
  v_primary_user UUID;
  v_location     UUID;
  v_asset        UUID;

  -- arrays
  v_assigned  JSONB;
  v_customers JSONB;

  -- custom id bits
  v_custom_id TEXT;
  v_year      INTEGER := EXTRACT(YEAR FROM current_date)::int;
  v_seq       INTEGER;
  v_try       INTEGER := 0;
BEGIN
  -- Required: title
  v_title := NULLIF(btrim(COALESCE(payload->>'title', payload->>'Title')), '');
  IF v_title IS NULL THEN
    RAISE EXCEPTION 'title is required';
  END IF;

  -- Priority (default NONE)
  v_priority := COALESCE(NULLIF(upper(COALESCE(payload->>'priority', payload->>'Priority')), ''), 'NONE');

  -- Description
  v_description := NULLIF(COALESCE(payload->>'description', payload->>'Description'), '');

  -- Dates (accept YYYY-MM-DD or full timestamptz; camel/snake)
  v_due_text       := COALESCE(payload->>'dueDate', payload->>'due_date');
  v_est_start_text := COALESCE(payload->>'estimatedStartDate', payload->>'estimated_start_date');

  IF v_due_text IS NOT NULL THEN
    v_due_date := CASE WHEN v_due_text ~ '^\d{4}-\d{2}-\d{2}$'
                       THEN (v_due_text::date)::timestamptz
                       ELSE v_due_text::timestamptz
                  END;
  END IF;

  IF v_est_start_text IS NOT NULL THEN
    v_est_start := CASE WHEN v_est_start_text ~ '^\d{4}-\d{2}-\d{2}$'
                        THEN (v_est_start_text::date)::timestamptz
                        ELSE v_est_start_text::timestamptz
                   END;
  END IF;

  -- Numerics / booleans
  v_est_duration       := COALESCE((payload->>'estimatedDuration')::double precision,
                                   (payload->>'estimated_duration')::double precision, 0);
  v_required_signature := COALESCE((payload->>'requiredSignature')::boolean,
                                   (payload->>'required_signature')::boolean, false);

  -- Foreign keys (accept camel/snake)
  v_primary_user := NULLIF(COALESCE(payload->>'primary_worker', payload->>'primaryWorker', payload->>'primary_user'), '')::uuid;
  v_location     := NULLIF(COALESCE(payload->>'location', payload->>'location_id'), '')::uuid;
  v_asset        := NULLIF(COALESCE(payload->>'asset', payload->>'asset_id'), '')::uuid;

  -- Provided custom_id?
  v_custom_id := COALESCE(payload->>'custom_id', payload->>'customId');

  IF v_custom_id IS NOT NULL AND v_custom_id <> '' THEN
    -- Single attempt; if duplicate, raise (client supplied it)
    INSERT INTO work_order (
      organisation_id, created_by_id, title, description, priority,
      estimated_duration, estimated_start_date, due_date, required_signature,
      primary_user_id, location_id, asset_id, status, custom_id
    )
    VALUES (
      org_id, created_by, v_title, v_description, v_priority,
      v_est_duration, v_est_start, v_due_date, v_required_signature,
      v_primary_user, v_location, v_asset, 'OPEN', v_custom_id
    )
    RETURNING id INTO v_id;

  ELSE
    -- Auto-generate with retry on unique_violation (race-safe)
    LOOP
      v_try := v_try + 1;

      -- Atomically fetch & bump the per-org, per-year counter
      INSERT INTO work_order_counters (organisation_id, year, next_seq)
      VALUES (org_id, v_year, 2)  -- first WO => seq=1 (next_seq becomes 2)
      ON CONFLICT (organisation_id, year)
      DO UPDATE SET next_seq = work_order_counters.next_seq + 1
      RETURNING next_seq - 1 INTO v_seq;

      v_custom_id := 'WO-' || v_year::text || '-' || lpad(v_seq::text, 4, '0');

      BEGIN
        INSERT INTO work_order (
          organisation_id, created_by_id, title, description, priority,
          estimated_duration, estimated_start_date, due_date, required_signature,
          primary_user_id, location_id, asset_id, status, custom_id
        )
        VALUES (
          org_id, created_by, v_title, v_description, v_priority,
          v_est_duration, v_est_start, v_due_date, v_required_signature,
          v_primary_user, v_location, v_asset, 'OPEN', v_custom_id
        )
        RETURNING id INTO v_id;

        EXIT; -- success
      EXCEPTION WHEN unique_violation THEN
        -- someone used this custom_id concurrently OR counter not yet aligned
        IF v_try >= 10 THEN
          RAISE EXCEPTION 'could not generate unique custom_id after % attempts for org %, year %', v_try, org_id, v_year;
        END IF;
        -- loop to try the next seq
      END;
    END LOOP;
  END IF;

  -- Arrays (after successful insert)
  v_assigned  := COALESCE(payload->'assigned_to', payload->'assignedTo');
  v_customers := COALESCE(payload->'customers',   payload->'customer_ids');

  IF v_assigned IS NOT NULL AND jsonb_typeof(v_assigned) = 'array' THEN
    INSERT INTO work_order_assigned_to (work_order_id, user_id)
    SELECT v_id, val::uuid
    FROM jsonb_array_elements_text(v_assigned) AS t(val)
    WHERE NULLIF(val, '') IS NOT NULL
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_customers IS NOT NULL AND jsonb_typeof(v_customers) = 'array' THEN
    INSERT INTO work_order_customers (work_order_id, customer_id)
    SELECT v_id, val::uuid
    FROM jsonb_array_elements_text(v_customers) AS t(val)
    WHERE NULLIF(val, '') IS NOT NULL
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_id;
END;
$$;


CREATE OR REPLACE FUNCTION public.update_work_order_from_json(
  p_org_id       UUID,
  p_work_order_id UUID,
  p_payload      JSONB,
  p_updated_by   UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  -- presence flags
  has_title               BOOLEAN := (p_payload ? 'title') OR (p_payload ? 'Title');
  has_description         BOOLEAN := (p_payload ? 'description') OR (p_payload ? 'Description');
  has_priority            BOOLEAN := (p_payload ? 'priority') OR (p_payload ? 'Priority');
  has_due_date            BOOLEAN := (p_payload ? 'dueDate') OR (p_payload ? 'due_date');
  has_est_start           BOOLEAN := (p_payload ? 'estimatedStartDate') OR (p_payload ? 'estimated_start_date');
  has_est_duration        BOOLEAN := (p_payload ? 'estimatedDuration') OR (p_payload ? 'estimated_duration');
  has_required_signature  BOOLEAN := (p_payload ? 'requiredSignature') OR (p_payload ? 'required_signature');
  has_primary_user        BOOLEAN := (p_payload ? 'primaryUser') OR (p_payload ? 'primary_user') OR (p_payload ? 'primary_worker') OR (p_payload ? 'primaryWorker');
  has_location            BOOLEAN := (p_payload ? 'location') OR (p_payload ? 'location_id');
  has_team                BOOLEAN := (p_payload ? 'team') OR (p_payload ? 'team_id');
  has_asset               BOOLEAN := (p_payload ? 'asset') OR (p_payload ? 'asset_id');
  has_archived            BOOLEAN := (p_payload ? 'archived');
  has_assigned_to         BOOLEAN := (p_payload ? 'assigned_to') OR (p_payload ? 'assignedTo');
  has_customers           BOOLEAN := (p_payload ? 'customers') OR (p_payload ? 'customer_ids');

  -- values
  v_title                 TEXT := COALESCE(p_payload->>'title', p_payload->>'Title');
  v_description           TEXT := COALESCE(p_payload->>'description', p_payload->>'Description');
  v_priority              TEXT := COALESCE(p_payload->>'priority', p_payload->>'Priority');

  v_due_text              TEXT := COALESCE(p_payload->>'dueDate', p_payload->>'due_date');
  v_est_start_text        TEXT := COALESCE(p_payload->>'estimatedStartDate', p_payload->>'estimated_start_date');
  v_due_date              TIMESTAMPTZ;
  v_est_start             TIMESTAMPTZ;

  v_est_duration          DOUBLE PRECISION;
  v_required_signature    BOOLEAN;
  v_archived              BOOLEAN;

  v_primary_user          UUID;
  v_location              UUID;
  v_team                  UUID;
  v_asset                 UUID;

  v_assigned              JSONB := COALESCE(p_payload->'assigned_to', p_payload->'assignedTo');
  v_customers             JSONB := COALESCE(p_payload->'customers',   p_payload->'customer_ids');

  v_exists                BOOLEAN;
BEGIN
  -- Ensure the work order exists and belongs to the org
  SELECT TRUE
  INTO v_exists
  FROM work_order
  WHERE id = p_work_order_id AND organisation_id = p_org_id
  LIMIT 1;

  IF NOT FOUND OR v_exists IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'work order % not found for organisation %', p_work_order_id, p_org_id
      USING ERRCODE = 'NO_DATA_FOUND';
  END IF;

  -- Parse dates if the key is present
  IF has_due_date THEN
    IF v_due_text IS NULL THEN
      v_due_date := NULL;
    ELSE
      v_due_date := CASE
        WHEN v_due_text ~ '^\d{4}-\d{2}-\d{2}$' THEN (v_due_text::date)::timestamptz
        ELSE v_due_text::timestamptz
      END;
    END IF;
  END IF;

  IF has_est_start THEN
    IF v_est_start_text IS NULL THEN
      v_est_start := NULL;
    ELSE
      v_est_start := CASE
        WHEN v_est_start_text ~ '^\d{4}-\d{2}-\d{2}$' THEN (v_est_start_text::date)::timestamptz
        ELSE v_est_start_text::timestamptz
      END;
    END IF;
  END IF;

  -- Numerics / booleans (apply defaults if provided null)
  IF has_est_duration THEN
    v_est_duration := COALESCE((p_payload->>'estimatedDuration')::double precision,
                               (p_payload->>'estimated_duration')::double precision,
                               0);  -- column is NOT NULL
  END IF;

  IF has_required_signature THEN
    v_required_signature := COALESCE((p_payload->>'requiredSignature')::boolean,
                                     (p_payload->>'required_signature')::boolean,
                                     FALSE); -- column is NOT NULL
  END IF;

  IF has_archived THEN
    v_archived := (p_payload->>'archived')::boolean;
  END IF;

  -- Foreign keys (null clears if explicitly provided null)
  IF has_primary_user THEN
    v_primary_user := NULLIF(COALESCE(p_payload->>'primaryUser', p_payload->>'primary_user',
                                      p_payload->>'primary_worker', p_payload->>'primaryWorker'), '')::uuid;
  END IF;

  IF has_location THEN
    v_location := NULLIF(COALESCE(p_payload->>'location', p_payload->>'location_id'), '')::uuid;
  END IF;

  IF has_team THEN
    v_team := NULLIF(COALESCE(p_payload->>'team', p_payload->>'team_id'), '')::uuid;
  END IF;

  IF has_asset THEN
    v_asset := NULLIF(COALESCE(p_payload->>'asset', p_payload->>'asset_id'), '')::uuid;
  END IF;

  -- Apply the update (patch semantics)
  UPDATE work_order SET
    title                 = CASE WHEN has_title              THEN v_title                    ELSE title                END,
    description           = CASE WHEN has_description        THEN v_description              ELSE description          END,
    priority              = CASE WHEN has_priority           THEN COALESCE(upper(v_priority), priority) ELSE priority END,  -- keep non-null
    due_date              = CASE WHEN has_due_date           THEN v_due_date                 ELSE due_date             END,
    estimated_start_date  = CASE WHEN has_est_start          THEN v_est_start                ELSE estimated_start_date END,
    estimated_duration    = CASE WHEN has_est_duration       THEN COALESCE(v_est_duration, estimated_duration) ELSE estimated_duration END,
    required_signature    = CASE WHEN has_required_signature THEN COALESCE(v_required_signature, required_signature) ELSE required_signature END,
    primary_user_id       = CASE WHEN has_primary_user       THEN v_primary_user            ELSE primary_user_id      END,
    location_id           = CASE WHEN has_location           THEN v_location                ELSE location_id          END,
    team_id               = CASE WHEN has_team               THEN v_team                    ELSE team_id              END,
    asset_id              = CASE WHEN has_asset              THEN v_asset                   ELSE asset_id             END,
    archived              = CASE WHEN has_archived           THEN COALESCE(v_archived, archived) ELSE archived END,
    updated_at            = now()
  WHERE id = p_work_order_id
    AND organisation_id = p_org_id;

  -- Replace assigned_to if present
  IF has_assigned_to THEN
    DELETE FROM work_order_assigned_to WHERE work_order_id = p_work_order_id;
    IF v_assigned IS NOT NULL AND jsonb_typeof(v_assigned) = 'array' THEN
      INSERT INTO work_order_assigned_to (work_order_id, user_id)
      SELECT p_work_order_id, (val)::uuid
      FROM (
        SELECT DISTINCT jsonb_array_elements_text(v_assigned) AS val
      ) s
      WHERE NULLIF(val, '') IS NOT NULL
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Replace customers if present
  IF has_customers THEN
    DELETE FROM work_order_customers WHERE work_order_id = p_work_order_id;
    IF v_customers IS NOT NULL AND jsonb_typeof(v_customers) = 'array' THEN
      INSERT INTO work_order_customers (work_order_id, customer_id)
      SELECT p_work_order_id, (val)::uuid
      FROM (
        SELECT DISTINCT jsonb_array_elements_text(v_customers) AS val
      ) s
      WHERE NULLIF(val, '') IS NOT NULL
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN p_work_order_id;
END;
$$;

-- Search users in an organisation using a JSON payload (see example below).
-- The function returns paginated rows plus total_count for the full result set.
CREATE OR REPLACE FUNCTION public.search_org_users(
  p_org_id   uuid,
  p_payload  jsonb
)
RETURNS TABLE (
  id          uuid,
  email       text,
  name        text,
  created_at  timestamptz,
  total_count bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_page_num   int  := COALESCE((p_payload->>'pageNum')::int, 0);
  v_page_size  int  := COALESCE((p_payload->>'pageSize')::int, 10);
  v_filters    jsonb := COALESCE(p_payload->'filterFields', '[]'::jsonb);

  v_limit      int;
  v_offset     int;

  v_sql        text;
  v_group      jsonb;
  v_alt        jsonb;

  v_field      text;
  v_col        text;
  v_op         text;
  v_val        text;

  v_group_sql  text;
  v_cond_sql   text;
BEGIN
  v_page_size := GREATEST(1, LEAST(v_page_size, 100));
  v_limit  := v_page_size;
  v_offset := GREATEST(0, v_page_num) * v_page_size;

  v_sql := '
    SELECT u.id, u.email, u.name, u.created_at,
           COUNT(*) OVER() AS total_count
    FROM users u
    JOIN org_memberships m ON m.user_id = u.id
    WHERE m.org_id = $1
  ';

  FOR v_group IN
    SELECT elem FROM jsonb_array_elements(v_filters) AS elem
  LOOP
    v_group_sql := NULL;

    v_field := COALESCE(v_group->>'field', '');
    v_col := CASE lower(v_field)
               WHEN 'email'     THEN 'u.email'
               WHEN 'name'      THEN 'u.name'
               WHEN 'firstname' THEN 'u.name'
               WHEN 'lastname'  THEN 'u.name'
               ELSE NULL
             END;

    v_op  := COALESCE(v_group->>'operation', 'eq');
    v_val := COALESCE(v_group->>'value', '');

    IF v_col IS NOT NULL THEN
      v_cond_sql :=
        CASE lower(v_op)
          WHEN 'eq' THEN format('%s = %L', v_col, v_val)
          WHEN 'cn' THEN format('%s ILIKE ''%%'' || %L || ''%%''', v_col, v_val)
          WHEN 'sw' THEN format('%s ILIKE %L || ''%%''', v_col, v_val)
          WHEN 'ew' THEN format('%s ILIKE ''%%'' || %L', v_col, v_val)
          ELSE       format('%s = %L', v_col, v_val)
        END;
      v_group_sql := v_cond_sql;
    END IF;

    FOR v_alt IN
      SELECT elem FROM jsonb_array_elements(COALESCE(v_group->'alternatives','[]'::jsonb)) AS elem
    LOOP
      v_field := COALESCE(v_alt->>'field', '');
      v_col := CASE lower(v_field)
                 WHEN 'email'     THEN 'u.email'
                 WHEN 'name'      THEN 'u.name'
                 WHEN 'firstname' THEN 'u.name'
                 WHEN 'lastname'  THEN 'u.name'
                 ELSE NULL
               END;
      IF v_col IS NULL THEN CONTINUE; END IF;

      v_op  := COALESCE(v_alt->>'operation', 'eq');
      v_val := COALESCE(v_alt->>'value', '');

      v_cond_sql :=
        CASE lower(v_op)
          WHEN 'eq' THEN format('%s = %L', v_col, v_val)
          WHEN 'cn' THEN format('%s ILIKE ''%%'' || %L || ''%%''', v_col, v_val)
          WHEN 'sw' THEN format('%s ILIKE %L || ''%%''', v_col, v_val)
          WHEN 'ew' THEN format('%s ILIKE ''%%'' || %L', v_col, v_val)
          ELSE       format('%s = %L', v_col, v_val)
        END;

      IF v_group_sql IS NULL THEN
        v_group_sql := v_cond_sql;
      ELSE
        v_group_sql := v_group_sql || ' OR ' || v_cond_sql;
      END IF;
    END LOOP;

    IF v_group_sql IS NOT NULL THEN
      v_sql := v_sql || ' AND (' || v_group_sql || ')';
    END IF;
  END LOOP;

  v_sql := v_sql || ' ORDER BY u.created_at DESC LIMIT $2 OFFSET $3';

  RETURN QUERY EXECUTE v_sql
    USING p_org_id, v_limit, v_offset;
END;
$$;
