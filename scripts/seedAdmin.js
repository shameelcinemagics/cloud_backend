// backend/scripts/seedAdmin.ts
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_EMAIL, ADMIN_PASSWORD, } = process.env;
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
    // 1) Create (or fetch) the admin user
    // Try to list existing users with that email (optional, for idempotency)
    const list = await supabase.auth.admin.listUsers();
    const existing = list.data.users.find(u => u.email?.toLowerCase() === ADMIN_EMAIL.toLowerCase());
    let userId;
    if (existing) {
        console.log('Admin user already exists:', existing.id);
        userId = existing.id;
    }
    else {
        const { data, error } = await supabase.auth.admin.createUser({
            email: ADMIN_EMAIL,
            password: ADMIN_PASSWORD,
            email_confirm: true, // allow immediate login
        });
        if (error || !data.user)
            throw new Error('createUser failed: ' + (error?.message || 'unknown'));
        userId = data.user.id;
        console.log('Created admin user:', userId);
    }
    // 2) Upsert user_roles -> role 'admin'
    const { data: roleRow, error: roleErr } = await supabase
        .from('roles').select('id').eq('slug', 'admin').maybeSingle();
    if (roleErr || !roleRow)
        throw new Error('Role "admin" missing; run SQL migrations first.');
    const { error: urErr } = await supabase
        .from('user_roles')
        .upsert({ user_id: userId, role_id: roleRow.id }, { onConflict: 'user_id' });
    if (urErr)
        throw new Error('user_roles upsert failed: ' + urErr.message);
    console.log(`✅ User ${userId} is now assigned the "admin" role.`);
}
main().catch(err => {
    console.error(err);
    process.exit(1);
});
//# sourceMappingURL=seedAdmin.js.map