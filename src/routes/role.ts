import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse } from '../utils/responses.js';

const router = Router();

router.get('/userrole', requireAuth, async (req, res) => {
    try {
        const { data, error } = await supabaseAdmin
            .from('roles')
            .select('*');
        if (error) {
            return serverError(res, 'Error fetching roles');
        }
        return successResponse(res, data);
    } catch (error) {
        return serverError(res, 'Server error');
    }
});

export default router;