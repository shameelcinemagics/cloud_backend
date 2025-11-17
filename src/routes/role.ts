import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse } from '../utils/responses.js';

const router = Router();

router.get('/userrole', requireAuth, async (req, res) => {
    try {
        // Get all roles
        const { data: roles, error: rolesError } = await supabaseAdmin
            .from('roles')
            .select('*')
            .order('slug');

        if (rolesError) {
            return serverError(res, 'Error fetching roles');
        }

        // Get role permissions
        const { data: rolePerms, error: permsError } = await supabaseAdmin
            .from('role_page_perms')
            .select(`
                role_id,
                perms_mask,
                pages:page_id (
                    slug,
                    label
                )
            `);

        if (permsError) {
            return serverError(res, 'Error fetching permissions');
        }

        // Group permissions by role
        const rolesWithPerms = roles?.map(role => ({
            ...role,
            page_permissions: rolePerms
                ?.filter((p: any) => p.role_id === role.id)
                .map((p: any) => ({
                    page_slug: p.pages?.slug,
                    perms_mask: p.perms_mask
                })) || []
        }));

        return successResponse(res, { roles: rolesWithPerms });
    } catch (error) {
        console.error('Error fetching roles:', error);
        return serverError(res, 'Server error');
    }
});

export default router;