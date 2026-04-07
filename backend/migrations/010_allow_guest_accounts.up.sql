-- Allow guest accounts with no email and no phone
ALTER TABLE parents DROP CONSTRAINT IF EXISTS parents_email_or_phone;
ALTER TABLE parents ADD COLUMN IF NOT EXISTS is_guest BOOLEAN NOT NULL DEFAULT FALSE;
