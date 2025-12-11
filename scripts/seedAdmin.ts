// backend/scripts/seedAdmin.ts
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { Client as PgClient } from 'pg';

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  ADMIN_EMAIL,
  ADMIN_PASSWORD,
  SUPABASE_DB_URL,
  DATABASE_URL,
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

async function ensureProfilesShape(): Promise<void> {
  const dbUrl = SUPABASE_DB_URL || DATABASE_URL;
  if (!dbUrl) {
    console.warn('profiles table may be missing expected columns; set SUPABASE_DB_URL to patch schema');
    return;
  }

  const client = new PgClient({ connectionString: dbUrl });
  await client.connect();

  // Inspect columns directly via pg; fallback to best-effort alter statements.
  const { rows: cols } = await client.query<{
    column_name: string;
  }>(
    `select column_name
     from information_schema.columns
     where table_schema = 'public' and table_name = 'profiles'`
  );
  const names = new Set(cols.map((c) => c.column_name));
  const needsUserId = !names.has('user_id');
  const needsUpdatedAt = !names.has('updated_at');
  const needsCreatedAt = !names.has('created_at');
  const needsRoleSlug = !names.has('role_slug');
  if (!needsUserId && !needsUpdatedAt && !needsCreatedAt && !needsRoleSlug) {
    await client.end();
    return;
  }

  try {
    if (needsUserId) {
      await client.query(`alter table public.profiles add column if not exists user_id uuid`);
      await client.query(`update public.profiles set user_id = id where user_id is null`);
    }
    if (needsCreatedAt) {
      await client.query(
        `alter table public.profiles add column if not exists created_at timestamptz default now()`
      );
    }
    if (needsRoleSlug) {
      await client.query(`alter table public.profiles add column if not exists role_slug text`);
    }
    if (needsUpdatedAt) {
      await client.query(
        `alter table public.profiles add column if not exists updated_at timestamptz default now()`
      );
    }
  } finally {
    await client.end();
  }
}

async function main() {
  console.log('Starting admin user seed...');

  await ensureProfilesShape();

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

  // 2) Ensure admin role exists (create if missing)
  let roleId: number | null = null;
  const { data: roleRow, error: roleErr } = await supabase
    .from('roles')
    .select('id')
    .eq('slug', 'admin')
    .maybeSingle();

  if (roleErr) {
    throw new Error('Failed to fetch roles: ' + roleErr.message);
  }

  if (roleRow?.id) {
    roleId = roleRow.id;
  } else {
    const { data: inserted, error: insertErr } = await supabase
      .from('roles')
      .insert({ slug: 'admin', label: 'Admin' })
      .select('id')
      .single();

    if (insertErr || !inserted) {
      const allRoles = await supabase.from('roles').select('*');
      console.error('Available roles:', allRoles.data);
      throw new Error('Could not create admin role: ' + (insertErr?.message || 'unknown error'));
    }
    roleId = inserted.id;
    console.log('Created admin role with id:', roleId);
  }

  // 3) Assign admin role to user
  const { error: urErr } = await supabase
    .from('user_roles')
    .upsert({ user_id: userId, role_id: roleId }, { onConflict: 'user_id' });
  if (urErr) throw new Error('user_roles upsert failed: ' + urErr.message);

  // 4) Ensure profiles row exists for the admin user
  const { error: profileErr } = await supabase
    .from('profiles')
    .upsert(
      { id: userId, user_id: userId, email: ADMIN_EMAIL },
      { onConflict: 'user_id' }
    );
  if (profileErr) throw new Error('profiles upsert failed: ' + profileErr.message);

  // 4) Grant full permissions on all pages to the admin role (and directly to the user)
  const { data: pages, error: pagesErr } = await supabase
    .from('pages')
    .select('id');
  if (pagesErr) {
    throw new Error('Failed to fetch pages: ' + pagesErr.message);
  }
  if (pages && pages.length > 0) {
    const fullMask = 15; // assume 4-bit perms
    const rolePermRows = pages.map(p => ({
      role_id: roleId,
      page_id: p.id,
      perms_mask: fullMask,
    }));
    const userPermRows = pages.map(p => ({
      user_id: userId,
      page_id: p.id,
      perms_mask: fullMask,
    }));

    const { error: rpErr } = await supabase
      .from('role_page_perms')
      .upsert(rolePermRows, { onConflict: 'role_id,page_id' });
    if (rpErr) throw new Error('role_page_perms upsert failed: ' + rpErr.message);

    const { error: upErr } = await supabase
      .from('user_page_perms')
      .upsert(userPermRows, { onConflict: 'user_id,page_id' });
    if (upErr) throw new Error('user_page_perms upsert failed: ' + upErr.message);

    console.log(`Granted full perms on ${pages.length} pages to admin role and user.`);
  } else {
    console.warn('No pages found; skipping page permission grants.');
  }

  console.log(`✅ User ${ADMIN_EMAIL} is now assigned the admin role with full permissions.`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
