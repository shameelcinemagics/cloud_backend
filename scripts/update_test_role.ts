import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://jubfnjvdgdevbkhsblln.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1YmZuanZkZ2RldmJraHNibGxuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkzOTgzNywiZXhwIjoyMDc4NTE1ODM3fQ.qjlaAf0uIZuct3hBGBKk8p3Uyum-XMQwAb-K3Oqxo3c'
);

async function updateTestRole() {
  const { data: testRole } = await supabase
    .from('roles')
    .select('id')
    .eq('slug', 'test')
    .single();

  if (!testRole) {
    console.log('Test role not found');
    return;
  }

  // Delete all existing permissions
  await supabase
    .from('role_page_perms')
    .delete()
    .eq('role_id', testRole.id);

  // Get dashboard page
  const { data: dashboardPage } = await supabase
    .from('pages')
    .select('id')
    .eq('slug', 'dashboard')
    .single();

  if (!dashboardPage) {
    console.log('Dashboard page not found');
    return;
  }

  // Add only dashboard:view
  await supabase
    .from('role_page_perms')
    .insert({
      role_id: testRole.id,
      page_id: dashboardPage.id,
      perms_mask: 2
    });

  console.log('✓ Updated test role to have only dashboard:view permission');

  // Verify
  const { data: perms } = await supabase
    .from('role_page_perms')
    .select('perms_mask, page_id')
    .eq('role_id', testRole.id);

  const { data: pages } = await supabase
    .from('pages')
    .select('id, slug')
    .in('id', (perms || []).map(p => p.page_id));

  console.log('\nTest role permissions:');
  perms?.forEach(perm => {
    const page = pages?.find(p => p.id === perm.page_id);
    const level = perm.perms_mask === 15 ? 'Admin' : perm.perms_mask === 2 ? 'View' : `Mask ${perm.perms_mask}`;
    console.log(`  - ${page?.slug}: ${level}`);
  });
}

updateTestRole().catch(console.error);
