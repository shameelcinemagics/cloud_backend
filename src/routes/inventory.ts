import { Router, type Request } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse, notFound } from '../utils/responses.js';

const router = Router();

// Get warehouse inventory with filters
router.get('/warehouse', requireAuth, async (req, res) => {
  try {
    const {
      warehouse_id,
      product_id,
      search,
      expiring_soon, // days
      limit = 100,
      offset = 0
    } = req.query;

    let query = supabaseAdmin
      .from('warehouse_stock')
      .select(`
        *,
        warehouses (id, name),
        products (*)
      `, { count: 'exact' });

    if (warehouse_id && typeof warehouse_id === 'string') {
      query = query.eq('warehouse_id', warehouse_id);
    }

    if (product_id && typeof product_id === 'string') {
      query = query.eq('product_id', product_id);
    }

    if (search && typeof search === 'string') {
      // We'll filter by product name after fetching
    }

    if (expiring_soon && typeof expiring_soon === 'string') {
      const days = Number(expiring_soon);
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + days);
      query = query.lte('expiry_date', futureDate.toISOString().split('T')[0]);
      query = query.gte('expiry_date', new Date().toISOString().split('T')[0]);
    }

    const { data, error, count } = await query
      .order('expiry_date', { ascending: true, nullsFirst: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching warehouse inventory:', error);
      return serverError(res, 'Failed to fetch warehouse inventory');
    }

    // Filter by product name if search is provided
    let filteredData = data;
    if (search && typeof search === 'string') {
      filteredData = data?.filter(item =>
        item.products?.name?.toLowerCase().includes(search.toLowerCase()) ||
        item.products?.partNo?.toLowerCase().includes(search.toLowerCase()) ||
        item.batch_number?.toLowerCase().includes(search.toLowerCase())
      );
    }

    return successResponse(res, { inventory: filteredData, total: count });
  } catch (err) {
    console.error('Error in get warehouse inventory:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get inventory summary by warehouse
router.get('/summary', requireAuth, async (req, res) => {
  try {
    const { warehouse_id } = req.query;

    let query = supabaseAdmin
      .from('warehouse_stock')
      .select(`
        product_id,
        quantity,
        products (*)
      `);

    if (warehouse_id && typeof warehouse_id === 'string') {
      query = query.eq('warehouse_id', warehouse_id);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching inventory summary:', error);
      return serverError(res, 'Failed to fetch inventory summary');
    }

    // Aggregate by product
    const summary = data?.reduce((acc: any[], item) => {
      const existing = acc.find(i => i.product_id === item.product_id);
      if (existing) {
        existing.total_quantity += item.quantity;
      } else {
        acc.push({
          product_id: item.product_id,
          product: item.products,
          total_quantity: item.quantity
        });
      }
      return acc;
    }, []);

    return successResponse(res, { inventory_summary: summary });
  } catch (err) {
    console.error('Error in get inventory summary:', err);
    return serverError(res, 'Internal server error');
  }
});

// Add inventory (manual adjustment or from PO)
router.post('/add', requireAuth, async (req: Request, res) => {
  try {
    const {
      warehouse_id,
      product_id,
      quantity,
      expiry_date,
      batch_number,
      manufacturing_date,
      notes
    } = req.body;

    if (!warehouse_id || !product_id) {
      return badRequest(res, 'Warehouse and product are required');
    }

    if (!quantity || quantity <= 0) {
      return badRequest(res, 'Valid quantity is required');
    }

    // Create inventory record
    const { data: inventoryData, error: inventoryError } = await supabaseAdmin
      .from('warehouse_stock')
      .insert({
        warehouse_id,
        product_id,
        quantity,
        expiry_date,
        batch_number
      })
      .select()
      .single();

    if (inventoryError) {
      console.error('Error adding inventory:', inventoryError);
      return serverError(res, 'Failed to add inventory');
    }

    // Record transaction
    await supabaseAdmin
      .from('inventory_transactions')
      .insert({
        warehouse_id,
        product_id,
        transaction_type: 'adjustment',
        quantity_change: quantity,
        quantity_before: 0,
        quantity_after: quantity,
        batch_number,
        expiry_date,
        notes: notes || 'Manual inventory addition',
        created_by: req.user?.id
      });

    return successResponse(res, { inventory: inventoryData }, 201);
  } catch (err) {
    console.error('Error in add inventory:', err);
    return serverError(res, 'Internal server error');
  }
});

// Remove/adjust inventory
router.post('/adjust', requireAuth, async (req: Request, res) => {
  try {
    const {
      inventory_id,
      quantity_change, // positive to add, negative to remove
      reason,
      notes
    } = req.body;

    if (!inventory_id) {
      return badRequest(res, 'Inventory ID is required');
    }

    if (quantity_change === undefined || quantity_change === 0) {
      return badRequest(res, 'Quantity change is required');
    }

    // Get current inventory
    const { data: currentInventory, error: fetchError } = await supabaseAdmin
      .from('warehouse_stock')
      .select('*, products(name)')
      .eq('id', inventory_id)
      .single();

    if (fetchError) {
      return notFound(res, 'Inventory record not found');
    }

    const newQuantity = currentInventory.quantity + quantity_change;

    if (newQuantity < 0) {
      return badRequest(res, 'Insufficient inventory');
    }

    // Update inventory
    const { data, error } = await supabaseAdmin
      .from('warehouse_stock')
      .update({ quantity: newQuantity })
      .eq('id', inventory_id)
      .select()
      .single();

    if (error) {
      console.error('Error adjusting inventory:', error);
      return serverError(res, 'Failed to adjust inventory');
    }

    // Record transaction
    await supabaseAdmin
      .from('inventory_transactions')
      .insert({
        warehouse_id: currentInventory.warehouse_id,
        product_id: currentInventory.product_id,
        transaction_type: reason || (quantity_change > 0 ? 'adjustment' : 'damaged'),
        quantity_change,
        quantity_before: currentInventory.quantity,
        quantity_after: newQuantity,
        batch_number: currentInventory.batch_number,
        expiry_date: currentInventory.expiry_date,
        notes,
        created_by: req.user?.id
      });

    return successResponse(res, { inventory: data });
  } catch (err) {
    console.error('Error in adjust inventory:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get inventory transactions (audit trail)
router.get('/transactions', requireAuth, async (req, res) => {
  try {
    const {
      warehouse_id,
      product_id,
      transaction_type,
      start_date,
      end_date,
      limit = 100,
      offset = 0
    } = req.query;

    let query = supabaseAdmin
      .from('inventory_transactions')
      .select(`
        *,
        warehouses (id, name),
        products (*),
        users (id, email)
      `, { count: 'exact' });

    if (warehouse_id && typeof warehouse_id === 'string') {
      query = query.eq('warehouse_id', warehouse_id);
    }

    if (product_id && typeof product_id === 'string') {
      query = query.eq('product_id', product_id);
    }

    if (transaction_type && typeof transaction_type === 'string') {
      query = query.eq('transaction_type', transaction_type);
    }

    if (start_date && typeof start_date === 'string') {
      query = query.gte('created_at', start_date);
    }

    if (end_date && typeof end_date === 'string') {
      query = query.lte('created_at', end_date);
    }

    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching transactions:', error);
      return serverError(res, 'Failed to fetch transactions');
    }

    return successResponse(res, { transactions: data, total: count });
  } catch (err) {
    console.error('Error in get transactions:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get expiring products
router.get('/expiring', requireAuth, async (req, res) => {
  try {
    const { warehouse_id, days = 30 } = req.query;

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + Number(days));

    let query = supabaseAdmin
      .from('warehouse_stock')
      .select(`
        *,
        warehouses (id, name),
        products (*)
      `)
      .gte('expiry_date', new Date().toISOString().split('T')[0])
      .lte('expiry_date', futureDate.toISOString().split('T')[0])
      .gt('quantity', 0);

    if (warehouse_id && typeof warehouse_id === 'string') {
      query = query.eq('warehouse_id', warehouse_id);
    }

    const { data, error } = await query.order('expiry_date', { ascending: true });

    if (error) {
      console.error('Error fetching expiring products:', error);
      return serverError(res, 'Failed to fetch expiring products');
    }

    return successResponse(res, { expiring_products: data });
  } catch (err) {
    console.error('Error in get expiring products:', err);
    return serverError(res, 'Internal server error');
  }
});

export default router;
