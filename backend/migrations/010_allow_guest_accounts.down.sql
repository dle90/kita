ALTER TABLE parents DROP COLUMN IF EXISTS is_guest;
ALTER TABLE parents ADD CONSTRAINT parents_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL);
