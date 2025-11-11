import type { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { has } from '../perms.js';
import { unauthorized, forbidden, serverError } from '../utils/responses.js';

export function requirePerm(pageSlug: string, neededMask: number) {
  return async (req: Request, res: Response, next: NextFunction) => {
    console.log('user:',req.user)
    try {
      const user = req.user;
      if (!user) return unauthorized(res, 'Unauthenticated');

      const { data, error } = await supabaseAdmin
        .from('user_effective_page_perms')
        .select('perms_mask')
        .eq('user_id', user.id)
        .eq('page_slug', pageSlug)
        .maybeSingle();

      if (error) return serverError(res, error.message);
      const mask = data?.perms_mask ?? 0;
      if (!has(mask, neededMask)) return forbidden(res);
      next();
    } catch (err) {
      console.error('Permission check error:', err);
      return serverError(res, 'Permission check failed');
    }
  };
}
