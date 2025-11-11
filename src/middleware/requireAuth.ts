import type { Request, Response, NextFunction } from 'express';
import { supabaseAnon } from '../supabase.js';
import { unauthorized, serverError } from '../utils/responses.js';

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return unauthorized(res, 'Missing token');

    const { data, error } = await supabaseAnon.auth.getUser(token);
    if (error || !data?.user) return unauthorized(res, 'Invalid token');

    req.user = data.user;
    next();
  } catch (err) {
    console.error('Auth error:', err);
    return serverError(res, 'Authentication failed');
  }
}
