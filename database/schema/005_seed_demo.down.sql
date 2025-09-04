BEGIN;

-- Remove memberships for demo users in demo org
DELETE FROM org_memberships om
WHERE om.org_id = (SELECT id FROM organisations WHERE slug='north-shore-wind')
  AND om.user_id IN (
    SELECT id FROM users
    WHERE email IN ('alice.tech@example.com','bob.elec@example.com','chris.hv@example.com','dana.pm@example.com')
  );

-- Remove demo identities (provider/local+subject=email)
DELETE FROM identities i
WHERE i.provider='local'
  AND i.subject IN ('alice.tech@example.com','bob.elec@example.com','chris.hv@example.com','dana.pm@example.com')
  AND i.user_id IN (
    SELECT id FROM users
    WHERE email IN ('alice.tech@example.com','bob.elec@example.com','chris.hv@example.com','dana.pm@example.com')
  );

-- Remove the demo users if no memberships/identities remain
DELETE FROM users u
WHERE u.email IN ('alice.tech@example.com','bob.elec@example.com','chris.hv@example.com','dana.pm@example.com')
  AND NOT EXISTS (SELECT 1 FROM org_memberships om WHERE om.user_id = u.id)
  AND NOT EXISTS (SELECT 1 FROM identities i WHERE i.user_id = u.id);

-- Remove the demo org if unused
DELETE FROM organisations o
WHERE o.slug='north-shore-wind'
  AND NOT EXISTS (SELECT 1 FROM org_memberships om WHERE om.org_id = o.id)
  AND NOT EXISTS (SELECT 1 FROM work_order w WHERE w.organisation_id = o.id);

COMMIT;
