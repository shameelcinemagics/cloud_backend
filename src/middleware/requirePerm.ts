import type { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { has } from '../perms.js';
import { unauthorized, forbidden, serverError } from '../utils/responses.js';

export function requirePerm(pageSlug: string, neededMask: number) {
  return async (req: Request, res: Response, next: NextFunction) => {
    console.log('user:', req.user);
    try {
      const user = req.user;
      if (!user) return unauthorized(res, 'Unauthenticated');

      // Get the page
      const { data: page, error: pageError } = await supabaseAdmin
        .from('pages')
        .select('id')
        .eq('slug', pageSlug)
        .maybeSingle();

      if (pageError) {
        console.error(`[PERM] Error fetching page '${pageSlug}':`, pageError);
        return serverError(res, pageError.message);
      }
      if (!page) {
        console.error(`[PERM] Page '${pageSlug}' not found in pages table`);
        return forbidden(res);
      }
      console.log(`[PERM] Page '${pageSlug}' found with id:`, page.id);

      // Check user's direct permissions first
      const { data: userPerm, error: userPermError } = await supabaseAdmin
        .from('user_page_perms')
        .select('perms_mask')
        .eq('user_id', user.id)
        .eq('page_id', page.id)
        .maybeSingle();

      if (userPermError) return serverError(res, userPermError.message);

      // If user has direct permission, use that
      if (userPerm) {
        const mask = userPerm.perms_mask ?? 0;
        if (!has(mask, neededMask)) return forbidden(res);
        return next();
      }

      // Otherwise, check role-based permissions
      const { data: userRole, error: roleError } = await supabaseAdmin
        .from('user_roles')
        .select('role_id')
        .eq('user_id', user.id)
        .maybeSingle();

      if (roleError) return serverError(res, roleError.message);

      if (userRole) {
        const { data: rolePerm, error: rolePermError } = await supabaseAdmin
          .from('role_page_perms')
          .select('perms_mask')
          .eq('role_id', userRole.role_id)
          .eq('page_id', page.id)
          .maybeSingle();

        if (rolePermError) return serverError(res, rolePermError.message);

        if (rolePerm) {
          const mask = rolePerm.perms_mask ?? 0;
          if (!has(mask, neededMask)) return forbidden(res);
          return next();
        }
      }

      // No permissions found
      return forbidden(res);
    } catch (err) {
      console.error('Permission check error:', err);
      return serverError(res, 'Permission check failed');
    }
  };
}
