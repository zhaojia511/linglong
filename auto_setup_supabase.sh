#!/bin/bash

set -e

echo "🚀 Automated Supabase Setup"
echo "================================"
echo ""

# Get Supabase project ref from URL
PROJECT_REF="krbobzpwgzxhnqssgwoy"

# Check if already linked
if [ -f "supabase/.temp/project-ref" ]; then
    echo "✓ Already linked to Supabase project"
else
    echo "📡 Linking to Supabase project..."
    cd supabase
    supabase link --project-ref "$PROJECT_REF" || {
        echo "⚠️  Link requires interactive login. Opening browser..."
        supabase login
        supabase link --project-ref "$PROJECT_REF"
    }
    cd ..
fi

echo ""
echo "📝 Creating migration file..."

# Create a new migration with the setup SQL
MIGRATION_FILE="supabase/migrations/$(date +%Y%m%d%H%M%S)_setup_rls.sql"

cat > "$MIGRATION_FILE" << 'EOF'
-- Enable RLS on existing tables
ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS persons_select_own ON public.persons;
DROP POLICY IF EXISTS persons_insert_own ON public.persons;
DROP POLICY IF EXISTS persons_update_own ON public.persons;
DROP POLICY IF EXISTS persons_delete_own ON public.persons;
DROP POLICY IF EXISTS sessions_select_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_insert_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_update_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_delete_own ON public.training_sessions;

-- Add missing columns
DO $$ BEGIN
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

-- Create RLS policies
CREATE POLICY persons_select_own ON public.persons 
    FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY persons_insert_own ON public.persons 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY persons_update_own ON public.persons 
    FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY persons_delete_own ON public.persons 
    FOR DELETE USING (auth.uid()::text = user_id);

CREATE POLICY sessions_select_own ON public.training_sessions 
    FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY sessions_insert_own ON public.training_sessions 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY sessions_update_own ON public.training_sessions 
    FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY sessions_delete_own ON public.training_sessions 
    FOR DELETE USING (auth.uid()::text = user_id);
EOF

echo "✓ Migration file created: $MIGRATION_FILE"
echo ""
echo "🚀 Pushing migration to Supabase..."

cd supabase
supabase db push

echo ""
echo "✅ Database setup complete!"
echo ""
echo "🌐 Your web app is ready at:"
echo "   https://ca86b7cb.linglong-test.pages.dev"
echo ""
