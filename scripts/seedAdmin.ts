// backend/scripts/seedAdmin.ts
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  ADMIN_EMAIL,
  ADMIN_PASSWORD,
} = process.env as Record<string, string>;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
}
if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD in .env before running this script');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

async function main() {
  console.log('Starting admin user seed...');

  // 1) Create or fetch the admin user
  const list = await supabase.auth.admin.listUsers();
  const existing = list.data.users.find(u => u.email?.toLowerCase() === ADMIN_EMAIL.toLowerCase());

  let userId: string;
  if (existing) {
    console.log('Admin user already exists:', existing.id);
    userId = existing.id;
  } else {
    const { data, error } = await supabase.auth.admin.createUser({
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      email_confirm: true,
      user_metadata: { role: 'admin' }
    });

    if (error) {
      throw new Error(`createUser failed: ${error.message}\n\nCheck:\n1. Supabase Dashboard → Authentication → Providers → Email is enabled\n2. Authentication → Settings → Disable email confirmations\n3. Project allows new signups`);
    }
    if (!data.user) throw new Error('createUser returned no user data');

    userId = data.user.id;
    console.log('Created admin user:', userId);
  }

  // 2) Find admin role
  const { data: roleRow, error: roleErr } = await supabase
    .from('roles').select('id').eq('slug', 'admin').maybeSingle();

  if (roleErr || !roleRow) {
    const allRoles = await supabase.from('roles').select('*');
    console.error('Available roles:', allRoles.data);
    throw new Error('Role "admin" not found; run SQL migrations first.');
  }

  // 3) Assign admin role to user
  const { error: urErr } = await supabase
    .from('user_roles')
    .upsert({ user_id: userId, role_id: roleRow.id }, { onConflict: 'user_id' });
  if (urErr) throw new Error('user_roles upsert failed: ' + urErr.message);

  console.log(`✅ User ${ADMIN_EMAIL} is now assigned the admin role.`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
