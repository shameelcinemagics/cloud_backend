import { supabaseAdmin } from '../src/supabase.js';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function runMigration() {
  try {
    const migrationPath = join(__dirname, '../supabase/migrations/20251127000000_add_supplier_country_code.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('Running migration: add_supplier_country_code.sql');
    console.log('SQL:', sql);

    const { data, error } = await supabaseAdmin.rpc('exec_sql', { sql_query: sql });

    if (error) {
      console.error('Migration failed:', error);
      process.exit(1);
    }

    console.log('Migration completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Error running migration:', err);
    process.exit(1);
  }
}

runMigration();
