-- Backfill legacy mobile-written session timestamps that were serialized as
-- local GMT+8 wall-clock values without a timezone offset.
--
-- Detection rule:
-- - legacy mobile sessions were titled like "Training Session YYYY-MM-DD HH:MM"
-- - the buggy rows stored that same wall-clock value directly in start_time as UTC
--
-- For example:
--   title      = Training Session 2026-05-06 11:46
--   start_time = 2026-05-06 11:46:18+00   -- wrong, should be 03:46:18+00

WITH legacy_sessions AS (
  SELECT id
  FROM public.training_sessions
  WHERE title ~ '^Training Session [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$'
    AND regexp_replace(title, '^Training Session ', '') = to_char(start_time AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI')
)
UPDATE public.training_sessions AS ts
SET start_time = ts.start_time - interval '8 hours',
    end_time = CASE
      WHEN ts.end_time IS NULL THEN NULL
      ELSE ts.end_time - interval '8 hours'
    END,
    created_at = ts.created_at - interval '8 hours',
    heart_rate_data = (
      SELECT COALESCE(
        jsonb_agg(
          CASE
            WHEN sample ? 'timestamp'
              AND jsonb_typeof(sample->'timestamp') = 'string'
              AND sample->>'timestamp' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$'
            THEN jsonb_set(
              sample,
              '{timestamp}',
              to_jsonb(((sample->>'timestamp')::timestamp - interval '8 hours') AT TIME ZONE 'UTC')
            )
            ELSE sample
          END
          ORDER BY ordinality
        ),
        '[]'::jsonb
      )
      FROM jsonb_array_elements(ts.heart_rate_data) WITH ORDINALITY AS samples(sample, ordinality)
    )
FROM legacy_sessions
WHERE ts.id = legacy_sessions.id;