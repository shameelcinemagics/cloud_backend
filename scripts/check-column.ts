import { supabaseAdmin } from '../src/supabase.js';

async function checkColumn() {
  try {
    console.log('Checking if country_code column exists...');

    const { data, error } = await supabaseAdmin
      .from('suppliers')
      .select('id, company_name, country_code')
      .limit(1);

    if (error) {
      if (error.message.includes('column "country_code" does not exist')) {
        console.log('❌ Column does NOT exist');
        console.log('\nPlease run this SQL in your Supabase SQL Editor:');
        console.log('---');
        console.log(`ALTER TABLE public.suppliers
ADD COLUMN country_code TEXT DEFAULT '+965';

UPDATE public.suppliers
SET country_code = '+965'
WHERE country = 'Kuwait';`);
        console.log('---');
      } else {
        console.error('Error querying suppliers:', error);
      }
      process.exit(1);
    }

    console.log('✅ Column EXISTS!');
    console.log('Sample data:', data);
    process.exit(0);
  } catch (err) {
    console.error('Unexpected error:', err);
    process.exit(1);
  }
}

checkColumn();
