import type { Request, Response, NextFunction } from 'express';
import { supabaseAnon } from '../supabase.js';
import { unauthorized, serverError } from '../utils/responses.js';

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    console.log(`[AUTH] ${req.method} ${req.path}`);
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;

    if (!token) {
      console.log('[AUTH] No token provided');
      return unauthorized(res, 'Missing token');
    }

    console.log('[AUTH] Validating token...');
    const { data, error } = await supabaseAnon.auth.getUser(token);

    if (error) {
      console.log('[AUTH] Token validation error:', error.message);
      return unauthorized(res, 'Invalid token');
    }

    if (!data?.user) {
      console.log('[AUTH] No user data returned');
      return unauthorized(res, 'Invalid token');
    }

    console.log('[AUTH] User authenticated:', data.user.email);
    req.user = data.user;
    next();
  } catch (err) {
    console.error('Auth error:', err);
    return serverError(res, 'Authentication failed');
  }
}
