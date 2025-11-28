import { Router } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse, notFound } from '../utils/responses.js';

const router = Router();

// Get all suppliers
router.get('/', requireAuth, async (req, res) => {
  try {
    const { status, search, limit = 50, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('suppliers')
      .select('*', { count: 'exact' });

    if (status && typeof status === 'string') {
      query = query.eq('status', status);
    }

    if (search && typeof search === 'string') {
      query = query.or(`company_name.ilike.%${search}%,email.ilike.%${search}%,contact_person.ilike.%${search}%`);
    }

    query = query
      .order('created_at', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    const { data, error, count } = await query;

    if (error) {
      console.error('Error fetching suppliers:', error);
      return serverError(res, 'Failed to fetch suppliers');
    }

    return successResponse(res, { suppliers: data, total: count });
  } catch (err) {
    console.error('Error in get suppliers:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get single supplier
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('suppliers')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Supplier not found');
      }
      console.error('Error fetching supplier:', error);
      return serverError(res, 'Failed to fetch supplier');
    }

    return successResponse(res, { supplier: data });
  } catch (err) {
    console.error('Error in get supplier:', err);
    return serverError(res, 'Internal server error');
  }
});

// Create supplier
router.post('/', requireAuth, async (req, res) => {
  try {
    const {
      company_name,
      email,
      company_registration,
      phone_number,
      country_code,
      fax_number,
      bank_name,
      bank_account_no,
      swift_code,
      company_intro,
      country,
      state_province,
      address_line1,
      address_line2,
      address_line3,
      postal_zip_code,
      city,
      contact_person,
      website,
      tax_id,
      payment_terms,
      status = 'active'
    } = req.body;

    if (!company_name || typeof company_name !== 'string' || company_name.trim() === '') {
      return badRequest(res, 'Company name is required');
    }

    const { data, error } = await supabaseAdmin
      .from('suppliers')
      .insert({
        company_name: company_name.trim(),
        email,
        company_registration,
        phone_number,
        country_code: country_code || '+965',
        fax_number,
        bank_name,
        bank_account_no,
        swift_code,
        company_intro,
        country: country || 'Kuwait',
        state_province,
        address_line1,
        address_line2,
        address_line3,
        postal_zip_code,
        city,
        contact_person,
        website,
        tax_id,
        payment_terms,
        status
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating supplier:', error);
      return serverError(res, 'Failed to create supplier');
    }

    return successResponse(res, { supplier: data }, 201);
  } catch (err) {
    console.error('Error in create supplier:', err);
    return serverError(res, 'Internal server error');
  }
});

// Update supplier
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Remove fields that shouldn't be updated directly
    delete updateData.id;
    delete updateData.created_at;
    delete updateData.updated_at;

    if (updateData.company_name && typeof updateData.company_name === 'string') {
      updateData.company_name = updateData.company_name.trim();
      if (updateData.company_name === '') {
        return badRequest(res, 'Company name cannot be empty');
      }
    }

    const { data, error } = await supabaseAdmin
      .from('suppliers')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Supplier not found');
      }
      console.error('Error updating supplier:', error);
      return serverError(res, 'Failed to update supplier');
    }

    return successResponse(res, { supplier: data });
  } catch (err) {
    console.error('Error in update supplier:', err);
    return serverError(res, 'Internal server error');
  }
});

// Delete supplier
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabaseAdmin
      .from('suppliers')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting supplier:', error);
      return serverError(res, 'Failed to delete supplier');
    }

    return successResponse(res, { message: 'Supplier deleted successfully' });
  } catch (err) {
    console.error('Error in delete supplier:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get supplier purchase history
router.get('/:id/history', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { start_date, end_date } = req.query;

    let query = supabaseAdmin
      .from('purchase_orders')
      .select(`
        id,
        reference,
        total_amount,
        status,
        created_at,
        purchase_order_items (
          product_id,
          quantity,
          unit_price,
          subtotal
        )
      `)
      .eq('supplier_id', id)
      .order('created_at', { ascending: false });

    if (start_date && typeof start_date === 'string') {
      query = query.gte('created_at', start_date);
    }

    if (end_date && typeof end_date === 'string') {
      query = query.lte('created_at', end_date);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching supplier history:', error);
      return serverError(res, 'Failed to fetch supplier history');
    }

    return successResponse(res, { history: data });
  } catch (err) {
    console.error('Error in get supplier history:', err);
    return serverError(res, 'Internal server error');
  }
});

export default router;
