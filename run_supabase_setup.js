#!/usr/bin/env node
const https = require('https');

const SUPABASE_URL = 'https://krbobzpwgzxhnqssgwoy.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyYm9ienB3Z3p4aG5xc3Nnd295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcyNDM1OTEsImV4cCI6MjA4MjgxOTU5MX0.4z4gEpUdVahjHfmSCiyTEaPS_vWljX9zzjKSi_Gm99E';

// You need to provide the service_role key as an environment variable
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SERVICE_KEY) {
  console.log('\n⚠️  Service key required for automated setup\n');
  console.log('Get your service_role key from:');
  console.log('https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/settings/api\n');
  console.log('Then run:');
  console.log('SUPABASE_SERVICE_KEY=your_key node run_supabase_setup.js\n');
  console.log('OR manually copy and run this SQL in Supabase SQL Editor:\n');
  console.log('https://supabase.com/dashboard/project/krbobzpwgzxhnqssgwoy/sql/new\n');
  
  const sql = `ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS persons_select_own ON public.persons;
DROP POLICY IF EXISTS persons_insert_own ON public.persons;
DROP POLICY IF EXISTS persons_update_own ON public.persons;
DROP POLICY IF EXISTS persons_delete_own ON public.persons;
DROP POLICY IF EXISTS sessions_select_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_insert_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_update_own ON public.training_sessions;
DROP POLICY IF EXISTS sessions_delete_own ON public.training_sessions;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='weight') THEN ALTER TABLE public.persons ADD COLUMN weight numeric; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='height') THEN ALTER TABLE public.persons ADD COLUMN height numeric; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='max_heart_rate') THEN ALTER TABLE public.persons ADD COLUMN max_heart_rate int; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='resting_heart_rate') THEN ALTER TABLE public.persons ADD COLUMN resting_heart_rate int; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='updated_at') THEN ALTER TABLE public.persons ADD COLUMN updated_at timestamptz DEFAULT now(); END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='title') THEN ALTER TABLE public.training_sessions ADD COLUMN title text DEFAULT 'Training Session'; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='notes') THEN ALTER TABLE public.training_sessions ADD COLUMN notes text; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='end_time') THEN ALTER TABLE public.training_sessions ADD COLUMN end_time timestamptz; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='min_heart_rate') THEN ALTER TABLE public.training_sessions ADD COLUMN min_heart_rate int; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='heart_rate_data') THEN ALTER TABLE public.training_sessions ADD COLUMN heart_rate_data jsonb DEFAULT '[]'::jsonb; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='synced') THEN ALTER TABLE public.training_sessions ADD COLUMN synced boolean DEFAULT false; END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='training_sessions' AND column_name='updated_at') THEN ALTER TABLE public.training_sessions ADD COLUMN updated_at timestamptz DEFAULT now(); END IF;
END $$;

CREATE POLICY persons_select_own ON public.persons FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY persons_insert_own ON public.persons FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY persons_update_own ON public.persons FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY persons_delete_own ON public.persons FOR DELETE USING (auth.uid()::text = user_id);
CREATE POLICY sessions_select_own ON public.training_sessions FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY sessions_insert_own ON public.training_sessions FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY sessions_update_own ON public.training_sessions FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY sessions_delete_own ON public.training_sessions FOR DELETE USING (auth.uid()::text = user_id);`;
  
  console.log('='.repeat(80));
  console.log(sql);
  console.log('='.repeat(80) + '\n');
  process.exit(1);
}

console.log('🚀 Running automated Supabase setup...\n');

const sqlStatements = [
  'ALTER TABLE public.persons ENABLE ROW LEVEL SECURITY',
  'ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY',
  'DROP POLICY IF EXISTS persons_select_own ON public.persons',
  'DROP POLICY IF EXISTS persons_insert_own ON public.persons',
  'DROP POLICY IF EXISTS persons_update_own ON public.persons',
  'DROP POLICY IF EXISTS persons_delete_own ON public.persons',
  'DROP POLICY IF EXISTS sessions_select_own ON public.training_sessions',
  'DROP POLICY IF EXISTS sessions_insert_own ON public.training_sessions',
  'DROP POLICY IF EXISTS sessions_update_own ON public.training_sessions',
  'DROP POLICY IF EXISTS sessions_delete_own ON public.training_sessions',
  `CREATE POLICY persons_select_own ON public.persons FOR SELECT USING (auth.uid()::text = user_id)`,
  `CREATE POLICY persons_insert_own ON public.persons FOR INSERT WITH CHECK (auth.uid()::text = user_id)`,
  `CREATE POLICY persons_update_own ON public.persons FOR UPDATE USING (auth.uid()::text = user_id)`,
  `CREATE POLICY persons_delete_own ON public.persons FOR DELETE USING (auth.uid()::text = user_id)`,
  `CREATE POLICY sessions_select_own ON public.training_sessions FOR SELECT USING (auth.uid()::text = user_id)`,
  `CREATE POLICY sessions_insert_own ON public.training_sessions FOR INSERT WITH CHECK (auth.uid()::text = user_id)`,
  `CREATE POLICY sessions_update_own ON public.training_sessions FOR UPDATE USING (auth.uid()::text = user_id)`,
  `CREATE POLICY sessions_delete_own ON public.training_sessions FOR DELETE USING (auth.uid()::text = user_id)`
];

async function executeSql(sql) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query: sql });
    
    const options = {
      hostname: 'krbobzpwgzxhnqssgwoy.supabase.co',
      path: '/rest/v1/rpc/query',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(body);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${body}`));
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function setup() {
  for (let i = 0; i < sqlStatements.length; i++) {
    const sql = sqlStatements[i];
    console.log(`[${i+1}/${sqlStatements.length}] ${sql.substring(0, 60)}...`);
    try {
      await executeSql(sql);
    } catch (err) {
      console.log(`   ⚠️  ${err.message}`);
    }
  }
  
  console.log('\n✅ Database setup complete!');
  console.log('Refresh your web app at: https://ca86b7cb.linglong-test.pages.dev\n');
}

setup().catch(err => {
  console.error('\n❌ Setup failed:', err.message);
  process.exit(1);
});
