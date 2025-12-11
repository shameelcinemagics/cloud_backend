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

// ===== WAREHOUSES =====

// Get all warehouses
router.get('/', requireAuth, async (req, res) => {
  try {
    const { search, limit = 50, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('warehouses')
      .select('*', { count: 'exact' });

    if (search && typeof search === 'string') {
      query = query.or(`name.ilike.%${search}%,address.ilike.%${search}%`);
    }

    query = query
      .order('is_preferred', { ascending: false })
      .order('created_at', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    const { data, error, count } = await query;

    if (error) {
      console.error('Error fetching warehouses:', error);
      return serverError(res, 'Failed to fetch warehouses');
    }

    return successResponse(res, { warehouses: data, total: count });
  } catch (err) {
    console.error('Error in get warehouses:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get single warehouse
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('warehouses')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Warehouse not found');
      }
      console.error('Error fetching warehouse:', error);
      return serverError(res, 'Failed to fetch warehouse');
    }

    return successResponse(res, { warehouse: data });
  } catch (err) {
    console.error('Error in get warehouse:', err);
    return serverError(res, 'Internal server error');
  }
});

// Create warehouse
router.post('/', requireAuth, async (req, res) => {
  try {
    const warehouseData = req.body;

    if (!warehouseData.name || warehouseData.name.trim() === '') {
      return badRequest(res, 'Warehouse name is required');
    }

    const { data, error } = await supabaseAdmin
      .from('warehouses')
      .insert(warehouseData)
      .select()
      .single();

    if (error) {
      console.error('Error creating warehouse:', error);
      return serverError(res, 'Failed to create warehouse');
    }

    return successResponse(res, { warehouse: data }, 201);
  } catch (err) {
    console.error('Error in create warehouse:', err);
    return serverError(res, 'Internal server error');
  }
});

// Update warehouse
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    delete updateData.id;
    delete updateData.created_at;
    delete updateData.updated_at;

    const { data, error } = await supabaseAdmin
      .from('warehouses')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Warehouse not found');
      }
      console.error('Error updating warehouse:', error);
      return serverError(res, 'Failed to update warehouse');
    }

    return successResponse(res, { warehouse: data });
  } catch (err) {
    console.error('Error in update warehouse:', err);
    return serverError(res, 'Internal server error');
  }
});

// Delete warehouse
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabaseAdmin
      .from('warehouses')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting warehouse:', error);
      return serverError(res, 'Failed to delete warehouse');
    }

    return successResponse(res, { message: 'Warehouse deleted successfully' });
  } catch (err) {
    console.error('Error in delete warehouse:', err);
    return serverError(res, 'Internal server error');
  }
});

// ===== WAREHOUSE STOCK =====

// Get warehouse stock
router.get('/:id/stock', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { category, product_id, low_stock_only } = req.query;

    let query = supabaseAdmin
      .from('warehouse_stock')
      .select('*')
      .eq('warehouse_id', id);

    if (product_id && typeof product_id === 'string') {
      query = query.eq('product_id', product_id);
    }

    if (low_stock_only === 'true') {
      query = query.filter('quantity', 'lte', supabaseAdmin.rpc('get_min_stock_level'));
    }

    const { data, error } = await query.order('quantity', { ascending: true });

    if (error) {
      console.error('Error fetching warehouse stock:', error);
      return serverError(res, 'Failed to fetch warehouse stock');
    }

    return successResponse(res, { stock: data });
  } catch (err) {
    console.error('Error in get warehouse stock:', err);
    return serverError(res, 'Internal server error');
  }
});

// Adjust warehouse stock
router.post('/:id/adjust-stock', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { product_id, quantity, adjustment_type, remark, unit_price } = req.body;

    if (!product_id) {
      return badRequest(res, 'Product ID is required');
    }

    if (typeof quantity !== 'number') {
      return badRequest(res, 'Quantity must be a number');
    }

    if (!adjustment_type) {
      return badRequest(res, 'Adjustment type is required');
    }

    // Get current stock
    const { data: currentStock, error: fetchError } = await supabaseAdmin
      .from('warehouse_stock')
      .select('quantity')
      .eq('warehouse_id', id)
      .eq('product_id', product_id)
      .single();

    const previousQuantity = currentStock?.quantity || 0;
    const newQuantity = previousQuantity + quantity;

    if (newQuantity < 0) {
      return badRequest(res, 'Insufficient stock for this adjustment');
    }

    // Upsert stock
    const { error: stockError } = await supabaseAdmin
      .from('warehouse_stock')
      .upsert({
        warehouse_id: id,
        product_id,
        quantity: newQuantity,
        unit_cost: unit_price || 0
      }, {
        onConflict: 'warehouse_id,product_id,batch_number'
      });

    if (stockError) {
      console.error('Error updating stock:', stockError);
      return serverError(res, 'Failed to update stock');
    }

    // Record adjustment
    const { error: adjustmentError } = await supabaseAdmin
      .from('stock_adjustments')
      .insert({
        warehouse_id: id,
        product_id,
        adjustment_type,
        quantity,
        previous_quantity: previousQuantity,
        new_quantity: newQuantity,
        unit_price,
        total_price: unit_price ? unit_price * Math.abs(quantity) : null,
        remark,
        adjusted_by: req.user?.id
      });

    if (adjustmentError) {
      console.error('Error recording adjustment:', adjustmentError);
      // Don't fail the request, stock was already updated
    }

    return successResponse(res, {
      message: 'Stock adjusted successfully',
      previous_quantity: previousQuantity,
      new_quantity: newQuantity
    });
  } catch (err) {
    console.error('Error in adjust stock:', err);
    return serverError(res, 'Internal server error');
  }
});

// Transfer stock between warehouses
router.post('/transfer', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { from_warehouse_id, to_warehouse_id, product_id, quantity } = req.body;

    if (!from_warehouse_id || !to_warehouse_id) {
      return badRequest(res, 'Both source and destination warehouses are required');
    }

    if (!product_id) {
      return badRequest(res, 'Product ID is required');
    }

    if (!quantity || quantity <= 0) {
      return badRequest(res, 'Quantity must be greater than 0');
    }

    // Check source stock
    const { data: sourceStock, error: sourceError } = await supabaseAdmin
      .from('warehouse_stock')
      .select('quantity')
      .eq('warehouse_id', from_warehouse_id)
      .eq('product_id', product_id)
      .single();

    if (sourceError || !sourceStock || sourceStock.quantity < quantity) {
      return badRequest(res, 'Insufficient stock in source warehouse');
    }

    // Deduct from source
    const { error: deductError } = await supabaseAdmin
      .from('warehouse_stock')
      .update({ quantity: sourceStock.quantity - quantity })
      .eq('warehouse_id', from_warehouse_id)
      .eq('product_id', product_id);

    if (deductError) {
      console.error('Error deducting from source:', deductError);
      return serverError(res, 'Failed to transfer stock');
    }

    // Add to destination
    const { data: destStock } = await supabaseAdmin
      .from('warehouse_stock')
      .select('quantity')
      .eq('warehouse_id', to_warehouse_id)
      .eq('product_id', product_id)
      .single();

    const newDestQuantity = (destStock?.quantity || 0) + quantity;

    const { error: addError } = await supabaseAdmin
      .from('warehouse_stock')
      .upsert({
        warehouse_id: to_warehouse_id,
        product_id,
        quantity: newDestQuantity
      }, {
        onConflict: 'warehouse_id,product_id,batch_number'
      });

    if (addError) {
      console.error('Error adding to destination:', addError);
      return serverError(res, 'Failed to complete transfer');
    }

    // Record adjustments for both warehouses
    await supabaseAdmin.from('stock_adjustments').insert([
      {
        warehouse_id: from_warehouse_id,
        product_id,
        adjustment_type: 'pick_up_to_transit',
        quantity: -quantity,
        previous_quantity: sourceStock.quantity,
        new_quantity: sourceStock.quantity - quantity,
        remark: `Transfer to warehouse ${to_warehouse_id}`,
        adjusted_by: req.user?.id
      },
      {
        warehouse_id: to_warehouse_id,
        product_id,
        adjustment_type: 'return_from_transit',
        quantity: quantity,
        previous_quantity: destStock?.quantity || 0,
        new_quantity: newDestQuantity,
        remark: `Transfer from warehouse ${from_warehouse_id}`,
        adjusted_by: req.user?.id
      }
    ]);

    return successResponse(res, { message: 'Stock transferred successfully' });
  } catch (err) {
    console.error('Error in transfer stock:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get stock adjustments/purchase history
router.get('/:id/adjustments', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { start_date, end_date, adjustment_type, product_id, limit = 50, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('stock_adjustments')
      .select('*', { count: 'exact' })
      .eq('warehouse_id', id);

    if (start_date && typeof start_date === 'string') {
      query = query.gte('adjustment_date', start_date);
    }

    if (end_date && typeof end_date === 'string') {
      query = query.lte('adjustment_date', end_date);
    }

    if (adjustment_type && typeof adjustment_type === 'string') {
      query = query.eq('adjustment_type', adjustment_type);
    }

    if (product_id && typeof product_id === 'string') {
      query = query.eq('product_id', product_id);
    }

    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching adjustments:', error);
      return serverError(res, 'Failed to fetch adjustments');
    }

    return successResponse(res, { adjustments: data, total: count });
  } catch (err) {
    console.error('Error in get adjustments:', err);
    return serverError(res, 'Internal server error');
  }
});

export default router;
