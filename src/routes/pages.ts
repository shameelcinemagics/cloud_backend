import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { unauthorized, serverError, successResponse } from '../utils/responses.js';

const router = Router();

router.get('/my-pages', async (req, res) => {
  try {
    const user = req.user;
    if (!user) return unauthorized(res, 'Unauthenticated');

    // Try to use the view first
    const { data: viewData, error: viewError } = await supabaseAdmin
      .from('user_effective_page_perms')
      .select('page_slug, perms_mask')
      .eq('user_id', user.id);

    // If view exists and works, use it
    if (!viewError && viewData) {
      console.log('Using view for user permissions');
      return successResponse(res, { pages: viewData });
    }

    // Fallback: Construct permissions manually (same logic as the view)
    console.log('View not available, using fallback query for user:', user.email);

    // 1. Get all pages
    const { data: pages, error: pagesError } = await supabaseAdmin
      .from('pages')
      .select('id, slug');

    if (pagesError) return serverError(res, pagesError.message);
    if (!pages) return successResponse(res, { pages: [] });

    // 2. Get user's roles
    const { data: userRoles, error: rolesError } = await supabaseAdmin
      .from('user_roles')
      .select('user_id, role_id');

    if (rolesError) {
      console.error('Error fetching user_roles:', rolesError);
      return serverError(res, rolesError.message);
    }

    // 3. Get all roles to check if user is admin
    const { data: allRoles, error: allRolesError } = await supabaseAdmin
      .from('roles')
      .select('id, slug');

    if (allRolesError) {
      console.error('Error fetching roles:', allRolesError);
      return serverError(res, allRolesError.message);
    }

    // 4. Check if user is admin
    const userRoleIds = userRoles?.filter(ur => ur.user_id === user.id).map(ur => ur.role_id) || [];
    const isAdmin = allRoles?.some(role => role.slug === 'admin' && userRoleIds.includes(role.id)) || false;

    // 5. Get role-based permissions
    let rolePagePerms: any[] = [];
    if (userRoleIds.length > 0) {
      const { data: rpp, error: rppError } = await supabaseAdmin
        .from('role_page_perms')
        .select('page_id, perms_mask')
        .in('role_id', userRoleIds);

      if (!rppError && rpp) {
        rolePagePerms = rpp;
      }
    }

    // 6. Get user-specific permissions
    const { data: userPagePerms, error: uppError } = await supabaseAdmin
      .from('user_page_perms')
      .select('page_id, perms_mask')
      .eq('user_id', user.id);

    if (uppError) {
      console.error('Error fetching user_page_perms:', uppError);
    }

    // 7. Aggregate permissions (same logic as the view)
    const aggregatedPerms: Record<number, number> = {};

    // Start with role permissions
    rolePagePerms.forEach((rp: any) => {
      const pageId = rp.page_id;
      aggregatedPerms[pageId] = aggregatedPerms[pageId]
        ? aggregatedPerms[pageId] | rp.perms_mask  // Bitwise OR
        : rp.perms_mask;
    });

    // Override with user-specific permissions
    userPagePerms?.forEach((up: any) => {
      aggregatedPerms[up.page_id] = up.perms_mask;
    });

    // 8. Build final permissions array
    const finalPermissions = pages.map((page) => {
      let permsMask: number = 0;

      if (isAdmin) {
        // Admin gets full CRUD (15) on all pages
        permsMask = 15;
      } else if (aggregatedPerms[page.id] !== undefined) {
        permsMask = aggregatedPerms[page.id] || 0;
      }

      return {
        page_slug: page.slug,
        perms_mask: permsMask
      };
    }).filter(p => p.perms_mask > 0); // Only return pages with permissions

    console.log(`Returning ${finalPermissions.length} pages for user ${user.email}`);
    return successResponse(res, { pages: finalPermissions });
  } catch (err) {
    console.error('Error fetching pages:', err);
    return serverError(res, 'Failed to fetch pages');
  }
});

export default router;
