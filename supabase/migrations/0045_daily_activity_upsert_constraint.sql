-- migration: 0045_daily_activity_upsert_constraint.sql
-- Description: Production-safe duplicate cleanup and idempotent UNIQUE constraint on daily_activity_summary(user_id, date)

-- 1. Automatic duplicate cleanup
-- Keeps the row with the highest synced_at; if multiple rows have the same
-- or NULL synced_at, id DESC is used solely as a deterministic tie-breaker.
WITH duplicates AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY user_id, date
           ORDER BY synced_at DESC NULLS LAST, id DESC
         ) as rn
  FROM public.daily_activity_summary
)
DELETE FROM public.daily_activity_summary
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- 2. Establish unique constraint (if it does not already exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conrelid = 'public.daily_activity_summary'::regclass 
      AND conname = 'daily_activity_summary_user_id_date_key'
  ) THEN
    ALTER TABLE public.daily_activity_summary
      ADD CONSTRAINT daily_activity_summary_user_id_date_key UNIQUE (user_id, date);
  END IF;
END $$;
