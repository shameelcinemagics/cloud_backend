import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { unauthorized, serverError, successResponse } from '../utils/responses.js';

const router = Router();

router.get('/my-pages', async (req, res) => {
  try {
    const user = req.user;
    if (!user) return unauthorized(res, 'Unauthenticated');

    // Get user's direct permissions
    const { data: userPerms, error: userPermsError } = await supabaseAdmin
      .from('user_page_perms')
      .select('page_id, perms_mask, pages:page_id(slug)')
      .eq('user_id', user.id);

    if (userPermsError) {
      console.error('Error fetching user permissions:', userPermsError);
      return serverError(res, userPermsError.message);
    }

    // Get user's role
    const { data: userRole, error: roleError } = await supabaseAdmin
      .from('user_roles')
      .select('role_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (roleError) {
      console.error('Error fetching user role:', roleError);
      return serverError(res, roleError.message);
    }

    // Get role-based permissions if user has a role
    let rolePerms: any[] = [];
    if (userRole) {
      const { data: rolePermsData, error: rolePermsError } = await supabaseAdmin
        .from('role_page_perms')
        .select('page_id, perms_mask, pages:page_id(slug)')
        .eq('role_id', userRole.role_id);

      if (rolePermsError) {
        console.error('Error fetching role permissions:', rolePermsError);
        return serverError(res, rolePermsError.message);
      }
      rolePerms = rolePermsData || [];
    }

    // Combine permissions (user permissions override role permissions)
    const permissionsMap = new Map<number, { page_slug: string; perms_mask: number }>();

    // First, add role permissions
    for (const perm of rolePerms) {
      if (perm.pages?.slug) {
        permissionsMap.set(perm.page_id, {
          page_slug: perm.pages.slug,
          perms_mask: perm.perms_mask,
        });
      }
    }

    // Then, override with user permissions
    for (const perm of userPerms || []) {
      if (perm.pages?.slug) {
        permissionsMap.set(perm.page_id, {
          page_slug: perm.pages.slug,
          perms_mask: perm.perms_mask,
        });
      }
    }

    // Convert map to array
    const pages = Array.from(permissionsMap.values());

    return successResponse(res, { pages });
  } catch (err) {
    console.error('Error fetching pages:', err);
    return serverError(res, 'Failed to fetch pages');
  }
});

export default router;
