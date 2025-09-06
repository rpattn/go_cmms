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
