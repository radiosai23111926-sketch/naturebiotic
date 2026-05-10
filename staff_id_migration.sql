-- ==============================================================================
-- STAFF ID SEQUENTIAL IDENTIFIER MIGRATION
-- Goal: Assign automatically incremented, never-recycled 4-digit compatible staff numbers.
-- Ensures existing records maintain order of creation ("first come first serve").
-- ==============================================================================

-- 1. Establish a globally incrementing thread-safe sequence
CREATE SEQUENCE IF NOT EXISTS staff_id_seq START 1;

-- 2. Inject the target nullable column into the profiles table 
-- (Done nullable first to allow precise ordering migration before locking default)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS staff_number INT;

-- 3. Populate historically existing records sorting by creation timestamps 
-- to preserve accurate historical hierarchy ("first come first served")
WITH ranked_profiles AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC) as seq_num
  FROM profiles
)
UPDATE profiles
SET staff_number = ranked_profiles.seq_num
FROM ranked_profiles
WHERE profiles.id = ranked_profiles.id;

-- 4. Calibrate the global sequence starting point to immediately follow the max legacy value
SELECT setval('staff_id_seq', (SELECT COALESCE(MAX(staff_number), 0) FROM profiles));

-- 5. Lock down future transactions by defining the increment logic as DEFAULT fallback 
ALTER TABLE profiles ALTER COLUMN staff_number SET DEFAULT nextval('staff_id_seq');

-- 6. Guarantee system-level integrity forbidding duplication
ALTER TABLE profiles ADD CONSTRAINT unique_staff_number UNIQUE (staff_number);
