import type { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { has } from '../perms.js';
import { unauthorized, forbidden, serverError } from '../utils/responses.js';

export function requirePerm(pageSlug: string, neededMask: number) {
  return async (req: Request, res: Response, next: NextFunction) => {
    console.log('Checking permission for user:', req.user?.email, 'on page:', pageSlug);
    try {
      const user = req.user;
      if (!user) return unauthorized(res, 'Unauthenticated');

      // Try to use the view first
      const { data: viewData, error: viewError } = await supabaseAdmin
        .from('user_effective_page_perms')
        .select('perms_mask')
        .eq('user_id', user.id)
        .eq('page_slug', pageSlug)
        .maybeSingle();

      // If view exists and works, use it
      if (!viewError && viewData) {
        const mask = viewData.perms_mask ?? 0;
        if (!has(mask, neededMask)) return forbidden(res);
        console.log('✓ Permission granted via view');
        next();
        return;
      }

      // Fallback: Check permissions manually
      console.log('View not available, checking permissions manually...');

      // 1. Get the page
      const { data: page, error: pageError } = await supabaseAdmin
        .from('pages')
        .select('id')
        .eq('slug', pageSlug)
        .maybeSingle();

      if (pageError) {
        console.error('Error fetching page:', pageError);
        return serverError(res, 'Failed to check permissions');
      }

      if (!page) {
        console.error('Page not found:', pageSlug);
        return forbidden(res);
      }

      // 2. Get user's roles
      const { data: userRoles, error: rolesError } = await supabaseAdmin
        .from('user_roles')
        .select('user_id, role_id')
        .eq('user_id', user.id);

      if (rolesError) {
        console.error('Error fetching user_roles:', rolesError);
        return serverError(res, 'Failed to check permissions');
      }

      // 3. Check if user is admin
      if (userRoles && userRoles.length > 0) {
        const roleIds = userRoles.map(ur => ur.role_id);
        const { data: roles, error: rolesCheckError } = await supabaseAdmin
          .from('roles')
          .select('slug')
          .in('id', roleIds);

        if (!rolesCheckError && roles?.some(r => r.slug === 'admin')) {
          console.log('✓ Permission granted - User is admin');
          next();
          return;
        }
      }

      // 4. Get role-based permissions
      let permsMask = 0;
      if (userRoles && userRoles.length > 0) {
        const roleIds = userRoles.map(ur => ur.role_id);
        const { data: rolePerms } = await supabaseAdmin
          .from('role_page_perms')
          .select('perms_mask')
          .in('role_id', roleIds)
          .eq('page_id', page.id);

        if (rolePerms && rolePerms.length > 0) {
          // Combine permissions using bitwise OR
          permsMask = rolePerms.reduce((acc, p) => acc | p.perms_mask, 0);
        }
      }

      // 5. Get user-specific permissions (overrides role permissions)
      const { data: userPerm } = await supabaseAdmin
        .from('user_page_perms')
        .select('perms_mask')
        .eq('user_id', user.id)
        .eq('page_id', page.id)
        .maybeSingle();

      if (userPerm) {
        permsMask = userPerm.perms_mask;
      }

      console.log(`User ${user.email} has perms_mask ${permsMask} on page ${pageSlug}, needs ${neededMask}`);

      if (!has(permsMask, neededMask)) {
        console.log('✗ Permission denied');
        return forbidden(res);
      }

      console.log('✓ Permission granted via fallback');
      next();
    } catch (err) {
      console.error('Permission check error:', err);
      return serverError(res, 'Permission check failed');
    }
  };
}
