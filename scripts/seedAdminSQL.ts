// Alternative admin seed script using direct SQL
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  ADMIN_EMAIL,
} = process.env as Record<string, string>;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
}
if (!ADMIN_EMAIL) {
  throw new Error('Set ADMIN_EMAIL in .env before running this script');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

async function main() {
  console.log('Starting admin role assignment...');
  console.log('Email:', ADMIN_EMAIL);

  // 1) Find existing user by email
  const { data: users, error: listError } = await supabase.auth.admin.listUsers();

  if (listError) {
    console.error('Error listing users:', listError);
    throw new Error('Failed to list users. Make sure your SERVICE_ROLE_KEY is correct.');
  }

  const existingUser = users.users.find(u => u.email?.toLowerCase() === ADMIN_EMAIL.toLowerCase());

  if (!existingUser) {
    console.error(`\n❌ User with email "${ADMIN_EMAIL}" not found.`);
    console.log('\nPlease create the user first:');
    console.log('1. Go to Supabase Dashboard → Authentication → Users');
    console.log('2. Click "Add user" → "Create new user"');
    console.log(`3. Enter email: ${ADMIN_EMAIL}`);
    console.log('4. Set a password and check "Auto Confirm User"');
    console.log('5. Run this script again\n');
    process.exit(1);
  }

  const userId = existingUser.id;
  console.log('✓ Found user:', userId);

  // 2) Get the admin role
  const { data: roleRow, error: roleErr } = await supabase
    .from('roles').select('id').eq('slug', 'admin').maybeSingle();

  if (roleErr || !roleRow) {
    console.error('Error fetching admin role:', roleErr);
    console.log('\nAvailable roles:');
    const allRoles = await supabase.from('roles').select('*');
    console.log(JSON.stringify(allRoles.data, null, 2));
    throw new Error('Role "admin" not found. Please run migrations first: migrations/001_core.sql');
  }

  console.log('✓ Found admin role:', roleRow.id);

  // 3) Assign admin role
  const { error: urErr } = await supabase
    .from('user_roles')
    .upsert({ user_id: userId, role_id: roleRow.id }, { onConflict: 'user_id' });

  if (urErr) {
    console.error('Error assigning role:', urErr);
    throw new Error('Failed to assign admin role: ' + urErr.message);
  }

  console.log(`\n✅ Success! User ${ADMIN_EMAIL} (${userId}) is now an admin.`);
  console.log('✅ This user now has full CRUD access to all pages.');
  console.log('\nYou can now login with this user through your application.\n');
}

main().catch(err => {
  console.error('\n❌ Error:', err.message || err);
  process.exit(1);
});
