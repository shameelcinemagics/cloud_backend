import { Router } from 'express';
import type { Request } from 'express';
import type { User } from '@supabase/supabase-js';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse, notFound } from '../utils/responses.js';

interface AuthRequest extends Request {
  user?: User;
}

const router = Router();

// Get all vending machines with filters
router.get('/', requireAuth, async (req, res) => {
  try {
    const {
      search,
      warehouse_id,
      status = 'active',
      limit = 50,
      offset = 0
    } = req.query;

    let query = supabaseAdmin
      .from('vending_machines')
      .select('*', { count: 'exact' });

    // Don't apply filters that might reference non-existent columns
    // if (search && typeof search === 'string') {
    //   query = query.or(`machine_code.ilike.%${search}%,location.ilike.%${search}%`);
    // }

    // if (warehouse_id && typeof warehouse_id === 'string') {
    //   query = query.eq('warehouse_id', warehouse_id);
    // }

    // if (status && typeof status === 'string' && status !== 'all') {
    //   query = query.eq('status', status);
    // }

    const { data, error, count } = await query
      // .order('machine_code', { ascending: true })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching vending machines:', error);
      return serverError(res, 'Failed to fetch vending machines');
    }

    // Optionally fetch warehouse details separately if warehouse_ids exist
    if (data && data.length > 0) {
      const warehouseIds = [...new Set(data.map((m: any) => m.warehouse_id).filter(Boolean))];

      if (warehouseIds.length > 0) {
        const { data: warehousesData } = await supabaseAdmin
          .from('warehouses')
          .select('id, name')
          .in('id', warehouseIds);

        if (warehousesData) {
          const warehousesMap = new Map(warehousesData.map(w => [w.id, w]));
          data.forEach((machine: any) => {
            if (machine.warehouse_id) {
              machine.warehouses = warehousesMap.get(machine.warehouse_id) || null;
            }
          });
        }
      }
    }

    return successResponse(res, { vending_machines: data, total: count });
  } catch (err) {
    console.error('Error in get vending machines:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get single vending machine with slots
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('vending_machines')
      .select(`
        *,
        slots (
          *,
          products (id, name, sku, selling_price)
        )
      `)
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Vending machine not found');
      }
      console.error('Error fetching vending machine:', error);
      return serverError(res, 'Failed to fetch vending machine');
    }

    // Fetch warehouse details separately if warehouse_id exists
    if (data && data.warehouse_id) {
      const { data: warehouseData } = await supabaseAdmin
        .from('warehouses')
        .select('id, name')
        .eq('id', data.warehouse_id)
        .single();

      if (warehouseData) {
        data.warehouses = warehouseData;
      }
    }

    return successResponse(res, { vending_machine: data });
  } catch (err) {
    console.error('Error in get vending machine:', err);
    return serverError(res, 'Internal server error');
  }
});

// Create vending machine
router.post('/', requireAuth, async (req: AuthRequest, res) => {
  try {
    const {
      name,
      machine_code,
      location,
      address,
      warehouse_id,
      latitude,
      longitude,
      total_slots = 0,
      notes,
      status = 'active'
    } = req.body;

    if (!name || name.trim() === '') {
      return badRequest(res, 'Machine name is required');
    }

    if (!machine_code || machine_code.trim() === '') {
      return badRequest(res, 'Machine code is required');
    }

    const { data, error } = await supabaseAdmin
      .from('vending_machines')
      .insert({
        name,
        machine_code,
        location,
        address,
        warehouse_id,
        latitude,
        longitude,
        total_slots,
        notes,
        status
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') { // Unique violation
        return badRequest(res, 'Machine code already exists');
      }
      console.error('Error creating vending machine:', error);
      return serverError(res, 'Failed to create vending machine');
    }

    return successResponse(res, { vending_machine: data }, 201);
  } catch (err) {
    console.error('Error in create vending machine:', err);
    return serverError(res, 'Internal server error');
  }
});

// Update vending machine
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    delete updateData.id;
    delete updateData.created_at;
    delete updateData.updated_at;

    const { data, error } = await supabaseAdmin
      .from('vending_machines')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Vending machine not found');
      }
      if (error.code === '23505') {
        return badRequest(res, 'Machine code already exists');
      }
      console.error('Error updating vending machine:', error);
      return serverError(res, 'Failed to update vending machine');
    }

    return successResponse(res, { vending_machine: data });
  } catch (err) {
    console.error('Error in update vending machine:', err);
    return serverError(res, 'Internal server error');
  }
});

// Delete vending machine
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    // Soft delete by setting status to inactive
    const { error } = await supabaseAdmin
      .from('vending_machines')
      .update({ status: 'offline' })
      .eq('id', id);

    if (error) {
      console.error('Error deleting vending machine:', error);
      return serverError(res, 'Failed to delete vending machine');
    }

    return successResponse(res, { message: 'Vending machine deleted successfully' });
  } catch (err) {
    console.error('Error in delete vending machine:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get machine inventory summary
router.get('/:id/inventory', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('slots')
      .select(`
        id,
        slot_number,
        current_quantity,
        max_capacity,
        products (id, name, sku, selling_price, category)
      `)
      .eq('vending_machine_id', id)
      .order('slot_number');

    if (error) {
      console.error('Error fetching machine inventory:', error);
      return serverError(res, 'Failed to fetch machine inventory');
    }

    return successResponse(res, { slots: data });
  } catch (err) {
    console.error('Error in get machine inventory:', err);
    return serverError(res, 'Internal server error');
  }
});

export default router;
