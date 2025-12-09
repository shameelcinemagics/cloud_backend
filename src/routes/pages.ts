import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { unauthorized, serverError, successResponse } from '../utils/responses.js';

const router = Router();

router.get('/my-pages', async (req, res) => {
  try {
    const user = req.user;
    if (!user) return unauthorized(res, 'Unauthenticated');

    const { data, error } = await supabaseAdmin
      .from('user_effective_page_perms')
      .select('page_slug, perms_mask')
      .eq('user_id', user.id);

    if (error) return serverError(res, error.message);
    return successResponse(res, { pages: data });
  } catch (err) {
    console.error('Error fetching pages:', err);
    return serverError(res, 'Failed to fetch pages');
  }
});

export default router;
