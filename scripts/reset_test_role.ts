import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://jubfnjvdgdevbkhsblln.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1YmZuanZkZ2RldmJraHNibGxuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjkzOTgzNywiZXhwIjoyMDc4NTE1ODM3fQ.qjlaAf0uIZuct3hBGBKk8p3Uyum-XMQwAb-K3Oqxo3c'
);

async function resetTestRole() {
  console.log('Step 1: Getting test role...');
  const { data: role } = await supabase
    .from('roles')
    .select('id, slug')
    .eq('slug', 'test')
    .single();

  if (!role) {
    console.log('Test role not found, will create new one');
  } else {
    console.log('Found role:', role);

    console.log('\nStep 2: Deleting role_page_perms for test role...');
    const { error: permsError } = await supabase
      .from('role_page_perms')
      .delete()
      .eq('role_id', role.id);

    if (permsError) {
      console.error('Error deleting permissions:', permsError);
    } else {
      console.log('✓ Permissions deleted');
    }

    console.log('\nStep 3: Deleting user_roles associations...');
    const { error: userRolesError } = await supabase
      .from('user_roles')
      .delete()
      .eq('role_id', role.id);

    if (userRolesError) {
      console.error('Error deleting user_roles:', userRolesError);
    } else {
      console.log('✓ User roles associations deleted');
    }

    console.log('\nStep 4: Deleting the test role...');
    const { error: roleError } = await supabase
      .from('roles')
      .delete()
      .eq('id', role.id);

    if (roleError) {
      console.error('Error deleting role:', roleError);
    } else {
      console.log('✓ Test role deleted');
    }
  }

  console.log('\nStep 5: Creating fresh test role with only dashboard:view...');

  // Create the role
  const { data: newRole, error: createError } = await supabase
    .from('roles')
    .insert({ slug: 'test', label: 'Test Role' })
    .select()
    .single();

  if (createError || !newRole) {
    console.error('Error creating role:', createError);
    return;
  }

  console.log('✓ Created role:', newRole);

  // Get dashboard page
  const { data: dashboardPage } = await supabase
    .from('pages')
    .select('id')
    .eq('slug', 'dashboard')
    .single();

  if (!dashboardPage) {
    console.error('Dashboard page not found');
    return;
  }

  // Add only dashboard:view permission (perms_mask = 2)
  const { error: permError } = await supabase
    .from('role_page_perms')
    .insert({
      role_id: newRole.id,
      page_id: dashboardPage.id,
      perms_mask: 2
    });

  if (permError) {
    console.error('Error adding permission:', permError);
  } else {
    console.log('✓ Added dashboard:view permission');
  }

  console.log('\nStep 6: Verifying final state...');
  const { data: finalPerms } = await supabase
    .from('role_page_perms')
    .select('perms_mask, page_id')
    .eq('role_id', newRole.id);

  const { data: pages } = await supabase
    .from('pages')
    .select('id, slug')
    .in('id', finalPerms?.map(p => p.page_id) || []);

  console.log('\nFinal permissions for test role:');
  finalPerms?.forEach(perm => {
    const page = pages?.find(p => p.id === perm.page_id);
    const level = perm.perms_mask === 15 ? 'Admin' : perm.perms_mask === 2 ? 'View' : `Mask ${perm.perms_mask}`;
    console.log(`  - ${page?.slug}: ${level}`);
  });

  console.log('\n✅ Test role successfully recreated with only dashboard:view');
}

resetTestRole().catch(console.error);
