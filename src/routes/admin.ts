import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requirePerm } from '../middleware/requirePerm.js';
import { PERM } from '../perms.js';
import { badRequest, serverError, successResponse } from '../utils/responses.js';
import { isValidUUID, isValidPassword, isNonEmptyString } from '../utils/validation.js';

const router = Router();

// Admin must have Update on "settings"
router.post('/create-user', requirePerm('settings', PERM.U), async (req, res) => {
  try {
    const { email, password, email_confirm, role_slug } = req.body;

    // Input validation
    if (!email || typeof email !== 'string') {
      return badRequest(res, 'Valid email is required');
    }
    if (!isValidPassword(password)) {
      return badRequest(res, 'Password must be at least 8 characters');
    }

    // Validate role_slug if provided
    let roleId: number | null = null;
    if (role_slug) {
      if (!isNonEmptyString(role_slug)) {
        return badRequest(res, 'Invalid role_slug');
      }

      // Check if role exists
      const { data: role, error: roleError } = await supabaseAdmin
        .from('roles')
        .select('id')
        .eq('slug', role_slug)
        .maybeSingle();

      if (roleError) return serverError(res, 'Failed to validate role');
      if (!role) return badRequest(res, `Role "${role_slug}" does not exist`);

      roleId = role.id;
    }

    // Create user
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: !!email_confirm,
    });

    if (error) return badRequest(res, error.message);
    if (!data.user) return serverError(res, 'User creation failed');

    const userId = data.user.id;

    // Assign role if provided
    if (roleId) {
      const { error: roleAssignError } = await supabaseAdmin
        .from('user_roles')
        .insert({ user_id: userId, role_id: roleId });

      if (roleAssignError) {
        console.error('Error assigning role:', roleAssignError);
        // User was created but role assignment failed
        return res.status(201).json({
          user: data.user,
          warning: 'User created but role assignment failed. Please assign role manually.',
          error: roleAssignError.message
        });
      }
    }

    return res.status(201).json({
      user: data.user,
      role_assigned: !!roleId,
      role_slug: roleId ? role_slug : null
    });
  } catch (err) {
    console.error('Error creating user:', err);
    return serverError(res, 'Failed to create user');
  }
});

router.post('/create-role', requirePerm('settings', PERM.U), async (req, res) => {
  try {
    const { slug, label, permissions } = req.body as {
      slug: string;
      label: string;
      permissions?: Array<{ page_slug: string; level: 'view' | 'admin' }>;
    };

    // Input validation
    if (!isNonEmptyString(slug)) {
      return badRequest(res, 'Valid slug is required');
    }
    if (!isNonEmptyString(label)) {
      return badRequest(res, 'Valid label is required');
    }

    // Validate slug format (lowercase, alphanumeric, underscores/hyphens only)
    const slugRegex = /^[a-z0-9_-]+$/;
    if (!slugRegex.test(slug)) {
      return badRequest(res, 'Slug must be lowercase alphanumeric with underscores or hyphens only');
    }

    // Validate permissions if provided
    const validLevels = ['view', 'admin'] as const;
    if (permissions) {
      if (!Array.isArray(permissions)) {
        return badRequest(res, 'permissions must be an array');
      }
      for (const perm of permissions) {
        if (!isNonEmptyString(perm.page_slug)) {
          return badRequest(res, 'Invalid page_slug in permissions array');
        }
        if (!validLevels.includes(perm.level)) {
          return badRequest(res, `Invalid level "${perm.level}". Must be: view or admin`);
        }
      }
    }

    // Check if role already exists
    const { data: existingRole } = await supabaseAdmin
      .from('roles')
      .select('id')
      .eq('slug', slug)
      .maybeSingle();

    if (existingRole) {
      return badRequest(res, `Role with slug "${slug}" already exists`);
    }

    // Insert the new role
    const { data, error } = await supabaseAdmin
      .from('roles')
      .insert([{ slug, label }])
      .select()
      .single();

    if (error) {
      console.error('Error inserting role:', error);
      return serverError(res, 'Failed to create role');
    }

    // If permissions provided, assign them to the role
    let permissionsAssigned = 0;
    if (permissions && permissions.length > 0) {
      // Get all pages
      const pageSlugs = permissions.map(p => p.page_slug);
      const { data: pages, error: pagesError } = await supabaseAdmin
        .from('pages')
        .select('id, slug')
        .in('slug', pageSlugs);

      if (pagesError) {
        return res.status(201).json({
          role: data,
          warning: 'Role created but failed to validate pages',
          error: pagesError.message
        });
      }

      if (!pages || pages.length === 0) {
        return res.status(201).json({
          role: data,
          warning: 'Role created but no valid pages found'
        });
      }

      // Create page map
      const pageMap = new Map(pages.map(p => [p.slug, p.id]));

      // Check for invalid page slugs
      const invalidPages = pageSlugs.filter(slug => !pageMap.has(slug));
      if (invalidPages.length > 0) {
        return res.status(201).json({
          role: data,
          warning: `Role created but some pages are invalid: ${invalidPages.join(', ')}`
        });
      }

      // Prepare records for insert
      const recordsToInsert = permissions.map(perm => {
        const pageId = pageMap.get(perm.page_slug);
        const perms_mask = perm.level === 'view' ? PERM.R : PERM.C | PERM.R | PERM.U | PERM.D;
        return {
          role_id: data.id,
          page_id: pageId!,
          perms_mask
        };
      });

      // Insert permissions
      const { error: permsError } = await supabaseAdmin
        .from('role_page_perms')
        .insert(recordsToInsert);

      if (permsError) {
        console.error('Error inserting role permissions:', permsError);
        return res.status(201).json({
          role: data,
          warning: 'Role created but failed to assign permissions',
          error: permsError.message
        });
      }

      permissionsAssigned = recordsToInsert.length;
    }

    return res.status(201).json({
      role: data,
      permissions_assigned: permissionsAssigned,
      permissions: permissions || []
    });
  } catch (err) {
    console.error('Error creating role:', err);
    return serverError(res, 'Failed to create role');
  }
});

router.post('/set-user-page', requirePerm('settings', PERM.U), async (req, res) => {
  try {
    const { user_id, page_slug, level } = req.body as {
      user_id: string; page_slug: string; level: 'view' | 'admin' | 'none';
    };

    // Input validation
    if (!isValidUUID(user_id)) {
      return badRequest(res, 'Invalid user_id format');
    }
    if (!isNonEmptyString(page_slug)) {
      return badRequest(res, 'Invalid page_slug');
    }
    const validLevels = ['view', 'admin', 'none'] as const;
    if (!validLevels.includes(level)) {
      return badRequest(res, 'Invalid level. Must be: view, admin, or none');
    }

    const { data: page, error: pageErr } = await supabaseAdmin
      .from('pages').select('id').eq('slug', page_slug).maybeSingle();
    if (pageErr) return serverError(res, pageErr.message);
    if (!page) return badRequest(res, 'Invalid page_slug');

    let perms_mask: number | null = null;
    if (level === 'view') perms_mask = PERM.R;
    else if (level === 'admin') perms_mask = PERM.C | PERM.R | PERM.U | PERM.D;

    if (perms_mask === null) {
      const { error } = await supabaseAdmin
        .from('user_page_perms').delete()
        .eq('user_id', user_id).eq('page_id', page.id);
      if (error) return serverError(res, error.message);
      return successResponse(res, { ok: true, level: 'none' });
    }

    const { error } = await supabaseAdmin
      .from('user_page_perms')
      .upsert({ user_id, page_id: page.id, perms_mask }, { onConflict: 'user_id,page_id' });

    if (error) return serverError(res, error.message);
    return successResponse(res, { ok: true, level, perms_mask });
  } catch (err) {
    console.error('Error setting user page permissions:', err);
    return serverError(res, 'Failed to set user page permissions');
  }
});

// Helper: promote any user to admin role
router.post('/assign-admin', requirePerm('settings', PERM.U), async (req, res) => {
  try {
    const { user_id } = req.body as { user_id: string };

    // Input validation
    if (!isValidUUID(user_id)) {
      return badRequest(res, 'Invalid user_id format');
    }

    // Look for 'admin' role (matches the migration)
    const { data: role } = await supabaseAdmin
      .from('roles').select('id').eq('slug', 'admin').maybeSingle();
    if (!role) return badRequest(res, 'Admin role missing. Please run migrations first.');

    const { error } = await supabaseAdmin
      .from('user_roles')
      .upsert({ user_id, role_id: role.id }, { onConflict: 'user_id' });

    if (error) return serverError(res, error.message);
    return successResponse(res, { ok: true });
  } catch (err) {
    console.error('Error assigning admin role:', err);
    return serverError(res, 'Failed to assign admin role');
  }
});

// Set role's default permissions on multiple pages (BULK)
router.post('/set-role-pages', requirePerm('settings', PERM.U), async (req, res) => {
  try {
    const { role_slug, permissions } = req.body as {
      role_slug: string;
      permissions: Array<{ page_slug: string; level: 'view' | 'admin' | 'none' }>;
    };

    // Input validation
    if (!isNonEmptyString(role_slug)) {
      return badRequest(res, 'Invalid role_slug');
    }
    if (!Array.isArray(permissions) || permissions.length === 0) {
      return badRequest(res, 'permissions must be a non-empty array');
    }

    // Validate each permission entry
    const validLevels = ['view', 'admin', 'none'] as const;
    for (const perm of permissions) {
      if (!isNonEmptyString(perm.page_slug)) {
        return badRequest(res, `Invalid page_slug in permissions array`);
      }
      if (!validLevels.includes(perm.level)) {
        return badRequest(res, `Invalid level "${perm.level}". Must be: view, admin, or none`);
      }
    }

    // Get role
    const { data: role, error: roleError } = await supabaseAdmin
      .from('roles').select('id').eq('slug', role_slug).maybeSingle();
    if (roleError) return serverError(res, roleError.message);
    if (!role) return badRequest(res, `Role "${role_slug}" not found`);

    // Get all pages
    const pageSlugs = permissions.map(p => p.page_slug);
    const { data: pages, error: pagesError } = await supabaseAdmin
      .from('pages')
      .select('id, slug')
      .in('slug', pageSlugs);

    if (pagesError) return serverError(res, pagesError.message);
    if (!pages || pages.length === 0) {
      return badRequest(res, 'No valid pages found');
    }

    // Create a map of page_slug -> page_id
    const pageMap = new Map(pages.map(p => [p.slug, p.id]));

    // Check for invalid page slugs
    const invalidPages = pageSlugs.filter(slug => !pageMap.has(slug));
    if (invalidPages.length > 0) {
      return badRequest(res, `Invalid page slugs: ${invalidPages.join(', ')}`);
    }

    // Prepare records for upsert and delete
    const recordsToUpsert: Array<{ role_id: number; page_id: number; perms_mask: number }> = [];
    const pagesToDelete: number[] = [];

    for (const perm of permissions) {
      const pageId = pageMap.get(perm.page_slug);
      if (!pageId) continue;

      let perms_mask: number | null = null;
      if (perm.level === 'view') perms_mask = PERM.R;
      else if (perm.level === 'admin') perms_mask = PERM.C | PERM.R | PERM.U | PERM.D;

      if (perms_mask === null) {
        // Mark for deletion
        pagesToDelete.push(pageId);
      } else {
        // Mark for upsert
        recordsToUpsert.push({
          role_id: role.id,
          page_id: pageId,
          perms_mask
        });
      }
    }

    // Delete permissions where level = 'none'
    if (pagesToDelete.length > 0) {
      const { error: deleteError } = await supabaseAdmin
        .from('role_page_perms')
        .delete()
        .eq('role_id', role.id)
        .in('page_id', pagesToDelete);

      if (deleteError) {
        console.error('Error deleting permissions:', deleteError);
        return serverError(res, 'Failed to remove some permissions');
      }
    }

    // Upsert permissions
    if (recordsToUpsert.length > 0) {
      const { error: upsertError } = await supabaseAdmin
        .from('role_page_perms')
        .upsert(recordsToUpsert, { onConflict: 'role_id,page_id' });

      if (upsertError) {
        console.error('Error upserting permissions:', upsertError);
        return serverError(res, 'Failed to set some permissions');
      }
    }

    return successResponse(res, {
      ok: true,
      role_slug,
      permissions_set: recordsToUpsert.length,
      permissions_removed: pagesToDelete.length,
      details: permissions.map(p => ({
        page_slug: p.page_slug,
        level: p.level,
        perms_mask: p.level === 'view' ? 2 : p.level === 'admin' ? 15 : 0
      }))
    });
  } catch (err) {
    console.error('Error setting role page permissions:', err);
    return serverError(res, 'Failed to set role page permissions');
  }
});

// Set role's default permissions on a single page (for backward compatibility)
router.post('/set-role-page', requirePerm('settings', PERM.U), async (req, res) => {
  try {
    const { role_slug, page_slug, level } = req.body as {
      role_slug: string;
      page_slug: string;
      level: 'view' | 'admin' | 'none';
    };

    // Input validation
    if (!isNonEmptyString(role_slug)) {
      return badRequest(res, 'Invalid role_slug');
    }
    if (!isNonEmptyString(page_slug)) {
      return badRequest(res, 'Invalid page_slug');
    }
    const validLevels = ['view', 'admin', 'none'] as const;
    if (!validLevels.includes(level)) {
      return badRequest(res, 'Invalid level. Must be: view, admin, or none');
    }

    // Get role
    const { data: role, error: roleError } = await supabaseAdmin
      .from('roles').select('id').eq('slug', role_slug).maybeSingle();
    if (roleError) return serverError(res, roleError.message);
    if (!role) return badRequest(res, `Role "${role_slug}" not found`);

    // Get page
    const { data: page, error: pageError } = await supabaseAdmin
      .from('pages').select('id').eq('slug', page_slug).maybeSingle();
    if (pageError) return serverError(res, pageError.message);
    if (!page) return badRequest(res, `Page "${page_slug}" not found`);

    // Calculate permissions mask
    let perms_mask: number | null = null;
    if (level === 'view') perms_mask = PERM.R;
    else if (level === 'admin') perms_mask = PERM.C | PERM.R | PERM.U | PERM.D;

    // Remove or update permissions
    if (perms_mask === null) {
      // Remove role permissions for this page
      const { error } = await supabaseAdmin
        .from('role_page_perms')
        .delete()
        .eq('role_id', role.id)
        .eq('page_id', page.id);

      if (error) return serverError(res, error.message);
      return successResponse(res, { ok: true, level: 'none' });
    }

    // Upsert role permissions
    const { error } = await supabaseAdmin
      .from('role_page_perms')
      .upsert(
        { role_id: role.id, page_id: page.id, perms_mask },
        { onConflict: 'role_id,page_id' }
      );

    if (error) return serverError(res, error.message);
    return successResponse(res, { ok: true, level, perms_mask });
  } catch (err) {
    console.error('Error setting role page permissions:', err);
    return serverError(res, 'Failed to set role page permissions');
  }
});

// Get all roles with their permissions
router.get('/roles', requirePerm('settings', PERM.R), async (_req, res) => {
  try {
    // Get all roles
    const { data: roles, error: rolesError } = await supabaseAdmin
      .from('roles')
      .select('*')
      .order('slug');

    if (rolesError) return serverError(res, rolesError.message);

    // Get role permissions
    const { data: rolePerms, error: permsError } = await supabaseAdmin
      .from('role_page_perms')
      .select(`
        role_id,
        perms_mask,
        pages:page_id (
          slug,
          label
        )
      `);

    if (permsError) return serverError(res, permsError.message);

    // Group permissions by role
    const rolesWithPerms = roles?.map(role => ({
      ...role,
      permissions: rolePerms
        ?.filter((p: any) => p.role_id === role.id)
        .map((p: any) => ({
          page_slug: p.pages?.slug,
          page_label: p.pages?.label,
          perms_mask: p.perms_mask
        })) || []
    }));

    return successResponse(res, { roles: rolesWithPerms });
  } catch (err) {
    console.error('Error fetching roles:', err);
    return serverError(res, 'Failed to fetch roles');
  }
});

// Get all users (admin only)
router.get('/users', requirePerm('users', PERM.R), async (_req, res) => {
  try {
    // Get users from auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.listUsers();

    if (authError) return serverError(res, 'Failed to fetch users');

    // Get user roles
    const { data: userRoles, error: rolesError } = await supabaseAdmin
      .from('user_roles')
      .select(`
        user_id,
        roles:role_id (
          id,
          slug,
          label
        )
      `);

    if (rolesError) return serverError(res, rolesError.message);

    // Combine data
    const users = authData.users.map(user => {
      const roleData = userRoles?.find((ur: any) => ur.user_id === user.id);
      return {
        id: user.id,
        email: user.email,
        created_at: user.created_at,
        last_sign_in_at: user.last_sign_in_at,
        role: roleData?.roles || null
      };
    });

    return successResponse(res, { users });
  } catch (err) {
    console.error('Error fetching users:', err);
    return serverError(res, 'Failed to fetch users');
  }
});

export default router;
