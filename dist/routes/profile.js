import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse } from '../utils/responses.js';
const router = Router();
// Get current user's profile
router.get('/me', requireAuth, async (req, res) => {
    try {
        const userId = req.user?.id;
        if (!userId) {
            return badRequest(res, 'User ID not found');
        }
        const { data: profile, error } = await supabaseAdmin
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
        if (error)
            return serverError(res, error.message);
        if (!profile)
            return badRequest(res, 'Profile not found');
        return successResponse(res, { profile });
    }
    catch (err) {
        console.error('Error fetching profile:', err);
        return serverError(res, 'Failed to fetch profile');
    }
});
// Update current user's profile
router.put('/me', requireAuth, async (req, res) => {
    try {
        const userId = req.user?.id;
        const { full_name, avatar_url, phone } = req.body;
        if (!userId) {
            return badRequest(res, 'User ID not found');
        }
        // Build update object (only include provided fields)
        const updates = {};
        if (full_name !== undefined)
            updates.full_name = full_name;
        if (avatar_url !== undefined)
            updates.avatar_url = avatar_url;
        if (phone !== undefined)
            updates.phone = phone;
        if (Object.keys(updates).length === 0) {
            return badRequest(res, 'No fields to update');
        }
        const { data: profile, error } = await supabaseAdmin
            .from('profiles')
            .update(updates)
            .eq('id', userId)
            .select()
            .single();
        if (error)
            return serverError(res, error.message);
        if (!profile)
            return badRequest(res, 'Profile not found');
        return successResponse(res, { profile });
    }
    catch (err) {
        console.error('Error updating profile:', err);
        return serverError(res, 'Failed to update profile');
    }
});
export default router;
//# sourceMappingURL=profile.js.map