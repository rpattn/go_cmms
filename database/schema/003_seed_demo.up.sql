INSERT INTO organisations (slug, name) VALUES ('acme', 'Acme Inc.')
ON CONFLICT (slug) DO NOTHING;
