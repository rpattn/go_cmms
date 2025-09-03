INSERT INTO organisations (slug, name) VALUES ('acme', 'Acme Inc.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO organisations (slug, name) VALUES ('testOrg', 'Test Org Inc.')
ON CONFLICT (slug) DO NOTHING;

