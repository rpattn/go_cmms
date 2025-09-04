BEGIN;

-- -------------------------------------------------------------------
-- Org & users
-- -------------------------------------------------------------------
INSERT INTO organisations (slug, name, ms_tenant_id)
VALUES ('north-shore-wind', 'North Shore Wind Farm', NULL)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO users (email, name) VALUES
  ('alice.tech@example.com',  'Alice Tech'),
  ('bob.elec@example.com',    'Bob Electrician'),
  ('chris.hv@example.com',    'Chris HV'),
  ('dana.pm@example.com',     'Dana Planner')
ON CONFLICT (email) DO NOTHING;

INSERT INTO identities (user_id, provider, subject)
SELECT u.id, 'local', u.email
FROM users u
WHERE u.email IN ('alice.tech@example.com','bob.elec@example.com','chris.hv@example.com','dana.pm@example.com')
ON CONFLICT (provider, subject) DO NOTHING;

INSERT INTO org_memberships (org_id, user_id, role)
SELECT o.id, u.id,
  CASE u.email
    WHEN 'alice.tech@example.com' THEN 'Owner'
    WHEN 'dana.pm@example.com'    THEN 'Admin'
    ELSE 'Member'
  END::org_role
FROM organisations o
JOIN users u ON o.slug = 'north-shore-wind'
WHERE u.email IN ('alice.tech@example.com','bob.elec@example.com','chris.hv@example.com','dana.pm@example.com')
ON CONFLICT (org_id, user_id) DO NOTHING;

-- -------------------------------------------------------------------
-- Lookups (idempotent without UNIQUEs)
-- -------------------------------------------------------------------
INSERT INTO work_order_categories (name)
SELECT x FROM (VALUES ('Corrective'),('Preventive'),('Inspection'),('Safety')) v(x)
WHERE NOT EXISTS (SELECT 1 FROM work_order_categories c WHERE c.name = v.x);

INSERT INTO locations (name)
SELECT x FROM (VALUES ('WTG-01'),('WTG-02'),('WTG-03'),('Substation'),('O&M Building'),('Switchyard')) v(x)
WHERE NOT EXISTS (SELECT 1 FROM locations l WHERE l.name = v.x);

INSERT INTO teams (name)
SELECT x FROM (VALUES ('Mechanical'),('Electrical'),('HV')) v(x)
WHERE NOT EXISTS (SELECT 1 FROM teams t WHERE t.name = v.x);

INSERT INTO customers (name, email)
SELECT * FROM (VALUES
  ('Site Owner','owner@example.com'),
  ('Grid Operator','dispatch@example.com')
) v(name,email)
WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.name = v.name);

INSERT INTO assets (name)
SELECT x FROM (VALUES
  ('Turbine T-01'),('Turbine T-02'),('Turbine T-03'),
  ('Main Transformer'),('SCADA Server'),('MV Switchgear')
) v(x)
WHERE NOT EXISTS (SELECT 1 FROM assets a WHERE a.name = v.x);

INSERT INTO preventive_maintenances (name)
SELECT x FROM (VALUES
  ('Monthly Turbine Inspection'),
  ('Quarterly Gearbox Oil Sample'),
  ('Annual HV Substation Inspection')
) v(x)
WHERE NOT EXISTS (SELECT 1 FROM preventive_maintenances p WHERE p.name = v.x);

INSERT INTO requests (title)
SELECT x FROM (VALUES
  ('High gearbox temperature alarm on T-02'),
  ('SCADA server security patch required'),
  ('Oil leak reported at main transformer')
) v(x)
WHERE NOT EXISTS (SELECT 1 FROM requests r WHERE r.title = v.x);

-- Files: this one kept without a conflict target is fine; or make it NOT EXISTS too
INSERT INTO files (path, filename)
SELECT * FROM (VALUES
  ('/uploads/photos','t02-gearbox-temp.jpg'),
  ('/uploads/signatures','tech-signature.png'),
  ('/uploads/reports','t01-monthly-inspection.pdf')
) v(path, filename)
WHERE NOT EXISTS (SELECT 1 FROM files f WHERE f.path = v.path AND f.filename = v.filename);


-- -------------------------------------------------------------------
-- Helper subselects
-- -------------------------------------------------------------------
-- org
-- (used repeatedly below)
-- SELECT id FROM organisations WHERE slug='north-shore-wind'

-- -------------------------------------------------------------------
-- 8 Work Orders (use subselects to resolve FKs)
-- -------------------------------------------------------------------
-- 1
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_preventive_maint_id, custom_id, image_id, signature_id,
  completed_by_id, completed_on, required_signature
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'Monthly turbine inspection - T-01',
  'Perform monthly checklist: yaw, pitch, lubrication points, nacelle housekeeping.',
  'LOW','COMPLETE',
  (SELECT id FROM work_order_categories WHERE name='Preventive'),
  (SELECT id FROM locations WHERE name='WTG-01'),
  (SELECT id FROM teams WHERE name='Mechanical'),
  (SELECT id FROM users WHERE email='alice.tech@example.com'),
  (SELECT id FROM assets WHERE name='Turbine T-01'),
  3.5, now() - interval '35 days', now() - interval '34 days',
  (SELECT id FROM preventive_maintenances WHERE name='Monthly Turbine Inspection'),
  'WO-2025-0001',
  (SELECT id FROM files WHERE filename='t02-gearbox-temp.jpg'),
  (SELECT id FROM files WHERE filename='tech-signature.png'),
  (SELECT id FROM users WHERE email='alice.tech@example.com'),
  now() - interval '33 days',
  TRUE
ON CONFLICT DO NOTHING;

-- 2
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_request_id, custom_id, image_id, required_signature
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='alice.tech@example.com'),
  'Investigate gearbox temperature alarm - T-02',
  'SCADA alarm trend shows spikes during high wind; inspect oil cooler and sensors.',
  'HIGH','IN_PROGRESS',
  (SELECT id FROM work_order_categories WHERE name='Corrective'),
  (SELECT id FROM locations WHERE name='WTG-02'),
  (SELECT id FROM teams WHERE name='Mechanical'),
  (SELECT id FROM users WHERE email='bob.elec@example.com'),
  (SELECT id FROM assets WHERE name='Turbine T-02'),
  5.0, now() - interval '2 days', now() + interval '1 day',
  (SELECT id FROM requests WHERE title='High gearbox temperature alarm on T-02'),
  'WO-2025-0002',
  (SELECT id FROM files WHERE filename='t02-gearbox-temp.jpg'),
  FALSE
ON CONFLICT DO NOTHING;

-- 3
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  custom_id, required_signature
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'LOTO verification before HV bay maintenance',
  'Verify lockout/tagout applied on 33kV feeders; document with photos and signatures.',
  'CRITICAL','OPEN',
  (SELECT id FROM work_order_categories WHERE name='Safety'),
  (SELECT id FROM locations WHERE name='Substation'),
  (SELECT id FROM teams WHERE name='HV'),
  (SELECT id FROM users WHERE email='chris.hv@example.com'),
  (SELECT id FROM assets WHERE name='MV Switchgear'),
  2.0, now() + interval '1 day', now() + interval '2 days',
  'WO-2025-0003',
  TRUE
ON CONFLICT DO NOTHING;

-- 4
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_preventive_maint_id, custom_id
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'Blade visual inspection - T-03',
  'Ground-based telephoto inspection of LE erosion and lightning receptors.',
  'MEDIUM','OPEN',
  (SELECT id FROM work_order_categories WHERE name='Inspection'),
  (SELECT id FROM locations WHERE name='WTG-03'),
  (SELECT id FROM teams WHERE name='Mechanical'),
  (SELECT id FROM users WHERE email='alice.tech@example.com'),
  (SELECT id FROM assets WHERE name='Turbine T-03'),
  4.0, now() + interval '3 days', now() + interval '5 days',
  (SELECT id FROM preventive_maintenances WHERE name='Monthly Turbine Inspection'),
  'WO-2025-0004'
ON CONFLICT DO NOTHING;

-- 5
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_preventive_maint_id, custom_id
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'Quarterly gearbox oil sample - T-02',
  'Draw sample from GBX main sump; label and send to lab; update trends.',
  'LOW','OPEN',
  (SELECT id FROM work_order_categories WHERE name='Preventive'),
  (SELECT id FROM locations WHERE name='WTG-02'),
  (SELECT id FROM teams WHERE name='Mechanical'),
  (SELECT id FROM users WHERE email='bob.elec@example.com'),
  (SELECT id FROM assets WHERE name='Turbine T-02'),
  1.5, now() + interval '6 days', now() + interval '7 days',
  (SELECT id FROM preventive_maintenances WHERE name='Quarterly Gearbox Oil Sample'),
  'WO-2025-0005'
ON CONFLICT DO NOTHING;

-- 6
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_request_id, custom_id, completed_by_id, completed_on, feedback
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'Apply SCADA server security patch',
  'Backup DB, apply vendor patch KB-2025-09, verify alarms and historian.',
  'HIGH','COMPLETE',
  (SELECT id FROM work_order_categories WHERE name='Corrective'),
  (SELECT id FROM locations WHERE name='O&M Building'),
  (SELECT id FROM teams WHERE name='Electrical'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  (SELECT id FROM assets WHERE name='SCADA Server'),
  2.0, now() - interval '5 days', now() - interval '4 days',
  (SELECT id FROM requests WHERE title='SCADA server security patch required'),
  'WO-2025-0006',
  (SELECT id FROM users WHERE email='bob.elec@example.com'),
  now() - interval '4 days',
  'Patched and rebooted. All services nominal.'
ON CONFLICT DO NOTHING;

-- 7
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_request_id, custom_id, image_id
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'Investigate main transformer oil leak',
  'Identify source near conservator level gauge; install drip tray; plan repair.',
  'HIGH','OPEN',
  (SELECT id FROM work_order_categories WHERE name='Corrective'),
  (SELECT id FROM locations WHERE name='Substation'),
  (SELECT id FROM teams WHERE name='HV'),
  (SELECT id FROM users WHERE email='chris.hv@example.com'),
  (SELECT id FROM assets WHERE name='Main Transformer'),
  6.0, now(), now() + interval '2 days',
  (SELECT id FROM requests WHERE title='Oil leak reported at main transformer'),
  'WO-2025-0007',
  (SELECT id FROM files WHERE filename='t02-gearbox-temp.jpg')
ON CONFLICT DO NOTHING;

-- 8
INSERT INTO work_order (
  organisation_id, created_by_id, title, description, priority, status,
  category_id, location_id, team_id, primary_user_id, asset_id,
  estimated_duration, estimated_start_date, due_date,
  parent_preventive_maint_id, custom_id, required_signature
)
SELECT
  (SELECT id FROM organisations WHERE slug='north-shore-wind'),
  (SELECT id FROM users WHERE email='dana.pm@example.com'),
  'Substation IR thermography survey',
  'Scan busbars, CTs, breaker terminals; record hotspots >15°C delta.',
  'MEDIUM','IN_PROGRESS',
  (SELECT id FROM work_order_categories WHERE name='Inspection'),
  (SELECT id FROM locations WHERE name='Switchyard'),
  (SELECT id FROM teams WHERE name='HV'),
  (SELECT id FROM users WHERE email='chris.hv@example.com'),
  (SELECT id FROM assets WHERE name='MV Switchgear'),
  3.0, now() - interval '1 day', now() + interval '1 day',
  (SELECT id FROM preventive_maintenances WHERE name='Annual HV Substation Inspection'),
  'WO-2025-0008',
  FALSE
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------------------
-- Junctions
-- -------------------------------------------------------------------
INSERT INTO work_order_assigned_to (work_order_id, user_id)
SELECT w.id, u.id
FROM work_order w
JOIN users u ON u.email = 'alice.tech@example.com'
WHERE w.custom_id IN ('WO-2025-0001','WO-2025-0004')
ON CONFLICT DO NOTHING;

INSERT INTO work_order_assigned_to (work_order_id, user_id)
SELECT w.id, u.id
FROM work_order w
JOIN users u ON u.email = 'bob.elec@example.com'
WHERE w.custom_id IN ('WO-2025-0002','WO-2025-0005','WO-2025-0006')
ON CONFLICT DO NOTHING;

INSERT INTO work_order_assigned_to (work_order_id, user_id)
SELECT w.id, u.id
FROM work_order w
JOIN users u ON u.email = 'chris.hv@example.com'
WHERE w.custom_id IN ('WO-2025-0003','WO-2025-0007','WO-2025-0008')
ON CONFLICT DO NOTHING;

INSERT INTO work_order_customers (work_order_id, customer_id)
SELECT w.id, c.id
FROM work_order w
JOIN customers c ON c.name = 'Site Owner'
WHERE w.custom_id IN ('WO-2025-0001','WO-2025-0004','WO-2025-0005','WO-2025-0008')
ON CONFLICT DO NOTHING;

INSERT INTO work_order_customers (work_order_id, customer_id)
SELECT w.id, c.id
FROM work_order w
JOIN customers c ON c.name = 'Grid Operator'
WHERE w.custom_id IN ('WO-2025-0002','WO-2025-0003','WO-2025-0006','WO-2025-0007')
ON CONFLICT DO NOTHING;

INSERT INTO work_order_files (work_order_id, file_id)
SELECT w.id, f.id
FROM work_order w
JOIN files f ON f.filename = 't01-monthly-inspection.pdf'
WHERE w.custom_id = 'WO-2025-0001'
ON CONFLICT DO NOTHING;

-- Optional: attach photo to gearbox alarm WO
INSERT INTO work_order_files (work_order_id, file_id)
SELECT w.id, f.id
FROM work_order w
JOIN files f ON f.filename = 't02-gearbox-temp.jpg'
WHERE w.custom_id = 'WO-2025-0002'
ON CONFLICT DO NOTHING;

COMMIT;
