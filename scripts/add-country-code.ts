import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing Supabase credentials in environment variables');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function addCountryCodeColumn() {
  try {
    console.log('Adding country_code column to suppliers table...');

    // Execute the SQL to add the column
    const { data, error } = await supabase.rpc('exec_sql', {
      sql_query: `
        ALTER TABLE public.suppliers
        ADD COLUMN IF NOT EXISTS country_code TEXT DEFAULT '+965';

        UPDATE public.suppliers
        SET country_code = '+965'
        WHERE country = 'Kuwait' AND country_code IS NULL;

        COMMENT ON COLUMN public.suppliers.country_code IS 'International phone country code (e.g., +965 for Kuwait)';
      `
    });

    if (error) {
      console.error('Error adding column:', error);

      // Try alternative approach - check if column exists first
      console.log('Trying direct column addition...');
      const { error: altError } = await supabase
        .from('suppliers')
        .select('country_code')
        .limit(1);

      if (altError && altError.message.includes('column "country_code" does not exist')) {
        console.log('Column does not exist. Please add it manually via Supabase dashboard.');
        console.log('SQL to run:');
        console.log(`
ALTER TABLE public.suppliers
ADD COLUMN country_code TEXT DEFAULT '+965';

UPDATE public.suppliers
SET country_code = '+965'
WHERE country = 'Kuwait' AND country_code IS NULL;
        `);
      } else {
        console.log('Column already exists or other error occurred.');
      }

      process.exit(1);
    }

    console.log('Successfully added country_code column!');
    process.exit(0);
  } catch (err) {
    console.error('Unexpected error:', err);
    process.exit(1);
  }
}

addCountryCodeColumn();
