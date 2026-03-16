#!/bin/bash

# Supabase credentials
SUPABASE_URL="https://krbobzpwgzxhnqssgwoy.supabase.co"
# Note: You need the service_role key (not anon key) for DDL operations
# Get it from: Supabase Dashboard > Settings > API > service_role key
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

if [ -z "$SERVICE_ROLE_KEY" ]; then
  echo "❌ Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set"
  echo ""
  echo "To get your service_role key:"
  echo "1. Go to https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/settings/api"
  echo "2. Copy the 'service_role' key (NOT the anon key)"
  echo "3. Run: export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key'"
  echo "4. Then run this script again"
  echo ""
  echo "OR run the SQL manually in Supabase SQL Editor:"
  echo "https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/sql/new"
  exit 1
fi

echo "🚀 Setting up Supabase database..."

SQL=$(cat <<'EOF'
ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS persons_select_own ON public.persons;
DROP POLICY IF EXISTS persons_insert_own ON public.persons;
DROP POLICY IF EXISTS persons_update_own ON public.persons;
DROP POLICY IF EXISTS persons_delete_own ON public.persons;

DROP POLICY IF EXISTS sessions_select_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_insert_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_update_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_delete_own ON public.training_sessions;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='weight') THEN
        ALTER TABLE public.persons ADD COLUMN weight numeric;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='height') THEN
        ALTER TABLE public.persons ADD COLUMN height numeric;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='max_heart_rate') THEN
        ALTER TABLE public.persons ADD COLUMN max_heart_rate int;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='resting_heart_rate') THEN
        ALTER TABLE public.persons ADD COLUMN resting_heart_rate int;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='updated_at') THEN
        ALTER TABLE public.persons ADD COLUMN updated_at timestamptz DEFAULT now();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='title') THEN
        ALTER TABLE public.training_sessions ADD COLUMN title text DEFAULT 'Training Session';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='notes') THEN
        ALTER TABLE public.training_sessions ADD COLUMN notes text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='end_time') THEN
        ALTER TABLE public.training_sessions ADD COLUMN end_time timestamptz;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='min_heart_rate') THEN
        ALTER TABLE public.training_sessions ADD COLUMN min_heart_rate int;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='heart_rate_data') THEN
        ALTER TABLE public.training_sessions ADD COLUMN heart_rate_data jsonb DEFAULT '[]'::jsonb;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='synced') THEN
        ALTER TABLE public.training_sessions ADD COLUMN synced boolean DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='updated_at') THEN
        ALTER TABLE public.training_sessions ADD COLUMN updated_at timestamptz DEFAULT now();
    END IF;
END $$;

CREATE POLICY persons_select_own ON public.persons
  FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY persons_insert_own ON public.persons
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY persons_update_own ON public.persons
  FOR UPDATE USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY persons_delete_own ON public.persons
  FOR DELETE USING (auth.uid()::text = user_id);

CREATE POLICY sessions_select_own ON public.training_sessions
  FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY sessions_insert_own ON public.training_sessions
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY sessions_update_own ON public.training_sessions
  FOR UPDATE USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY sessions_delete_own ON public.training_sessions
  FOR DELETE USING (auth.uid()::text = user_id);
EOF
)

curl -X POST "${SUPABASE_URL}/rest/v1/rpc/exec_sql" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": $(echo "$SQL" | jq -Rs .)}"

echo ""
echo "✅ Setup complete! Refresh your web app."
