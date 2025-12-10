import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://jubfnjvdgdevbkhsblln.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1YmZuanZkZ2RldmJraHNibGxuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkzOTgzNywiZXhwIjoyMDc4NTE1ODM3fQ.qjlaAf0uIZuct3hBGBKk8p3Uyum-XMQwAb-K3Oqxo3c'
);

async function checkRolePerms() {
  console.log('Checking role_page_perms for test role...\n');

  // Get test role
  const { data: role, error: roleError } = await supabase
    .from('roles')
    .select('id, slug')
    .eq('slug', 'test')
    .single();

  if (roleError || !role) {
    console.log('Test role not found');
    return;
  }

  console.log('Test role:', role);

  // Get permissions from role_page_perms
  const { data: perms } = await supabase
    .from('role_page_perms')
    .select('perms_mask, page_id')
    .eq('role_id', role.id);

  console.log('\nPermissions in role_page_perms table:', perms);

  if (perms && perms.length > 0) {
    // Get page details
    const { data: pages } = await supabase
      .from('pages')
      .select('id, slug')
      .in('id', perms.map(p => p.page_id));

    console.log('\nPages with permissions:');
    perms.forEach(perm => {
      const page = pages?.find(p => p.id === perm.page_id);
      const level = perm.perms_mask === 15 ? 'Admin' : perm.perms_mask === 2 ? 'View' : `Mask ${perm.perms_mask}`;
      console.log(`  - ${page?.slug}: ${level}`);
    });
  }
}

checkRolePerms().catch(console.error);
