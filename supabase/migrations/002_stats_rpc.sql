CREATE OR REPLACE FUNCTION public.get_training_stats(
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL,
  p_person_id text DEFAULT NULL
)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT json_build_object(
    'totalSessions', COUNT(*),
    'totalDuration', COALESCE(SUM(duration), 0),
    'totalCalories', COALESCE(SUM(calories), 0),
    'avgHeartRate', ROUND(AVG(avg_heart_rate)),
    'maxHeartRate', MAX(max_heart_rate),
    'trainingTypes', (
      SELECT json_object_agg(training_type, cnt)
      FROM (
        SELECT training_type, COUNT(*) as cnt
        FROM public.training_sessions
        WHERE user_id::text = auth.uid()::text
          AND (p_start_date IS NULL OR start_time >= p_start_date)
          AND (p_end_date IS NULL OR start_time <= p_end_date)
          AND (p_person_id IS NULL OR person_id = p_person_id)
        GROUP BY training_type
      ) t
    )
  )
  FROM public.training_sessions
  WHERE user_id::text = auth.uid()::text
    AND (p_start_date IS NULL OR start_time >= p_start_date)
    AND (p_end_date IS NULL OR start_time <= p_end_date)
    AND (p_person_id IS NULL OR person_id = p_person_id);
$$;
