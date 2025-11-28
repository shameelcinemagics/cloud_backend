import { Router } from 'express';
import type { Request } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse, notFound } from '../utils/responses.js';

interface AuthRequest extends Request {
  user?: { id: string };
}

const router = Router();

// Get all delivery routes with filters
router.get('/', requireAuth, async (req, res) => {
  try {
    const {
      start_date,
      end_date,
      route_name,
      warehouse_id,
      delivery_status,
      product_id,
      machine_id,
      limit = 50,
      offset = 0
    } = req.query;

    let query = supabaseAdmin
      .from('delivery_routes')
      .select(`
        *,
        warehouses (id, name),
        delivery_route_items (*)
      `, { count: 'exact' });

    if (start_date && typeof start_date === 'string') {
      query = query.gte('route_date', start_date);
    }

    if (end_date && typeof end_date === 'string') {
      query = query.lte('route_date', end_date);
    }

    if (route_name && typeof route_name === 'string') {
      query = query.ilike('name', `%${route_name}%`);
    }

    if (warehouse_id && typeof warehouse_id === 'string') {
      query = query.eq('warehouse_id', warehouse_id);
    }

    if (delivery_status && typeof delivery_status === 'string') {
      query = query.eq('delivery_status', delivery_status);
    }

    const { data, error, count } = await query
      .order('route_date', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching delivery routes:', error);
      return serverError(res, 'Failed to fetch delivery routes');
    }

    // Fetch person_in_charge details separately for each route
    if (data && data.length > 0) {
      const userIds = [...new Set(data.map((r: any) => r.person_in_charge_id).filter(Boolean))];

      if (userIds.length > 0) {
        const { data: usersData } = await supabaseAdmin.auth.admin.listUsers();
        const usersMap = new Map(
          usersData.users
            .filter(u => userIds.includes(u.id))
            .map(u => [u.id, { id: u.id, email: u.email }])
        );

        data.forEach((route: any) => {
          if (route.person_in_charge_id) {
            route.person_in_charge = usersMap.get(route.person_in_charge_id) || null;
          }
        });
      }
    }

    return successResponse(res, { delivery_routes: data, total: count });
  } catch (err) {
    console.error('Error in get delivery routes:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get single delivery route with items
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('delivery_routes')
      .select(`
        *,
        warehouses (id, name),
        delivery_route_items (*)
      `)
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Delivery route not found');
      }
      console.error('Error fetching delivery route:', error);
      return serverError(res, 'Failed to fetch delivery route');
    }

    // Fetch person_in_charge details separately
    if (data && data.person_in_charge_id) {
      const { data: usersData } = await supabaseAdmin.auth.admin.listUsers();
      const user = usersData.users.find(u => u.id === data.person_in_charge_id);
      if (user) {
        data.person_in_charge = { id: user.id, email: user.email };
      }
    }

    return successResponse(res, { delivery_route: data });
  } catch (err) {
    console.error('Error in get delivery route:', err);
    return serverError(res, 'Internal server error');
  }
});

// Create delivery route
router.post('/', requireAuth, async (req: AuthRequest, res) => {
  try {
    const {
      name,
      description,
      person_in_charge_id,
      warehouse_id,
      machines = [],
      route_date,
      items = []
    } = req.body;

    if (!name || name.trim() === '') {
      return badRequest(res, 'Route name is required');
    }

    if (!warehouse_id) {
      return badRequest(res, 'Warehouse is required');
    }

    if (!machines || machines.length === 0) {
      return badRequest(res, 'At least one machine must be selected');
    }

    // Generate kitting code
    const { data: kittingCode, error: kittingError } = await supabaseAdmin
      .rpc('generate_kitting_code');

    if (kittingError) {
      console.error('Error generating kitting code:', kittingError);
    }

    // Create delivery route
    const { data: routeData, error: routeError } = await supabaseAdmin
      .from('delivery_routes')
      .insert({
        name,
        description,
        person_in_charge_id: person_in_charge_id || null,
        warehouse_id,
        machines,
        route_date: route_date || new Date().toISOString().split('T')[0],
        kitting_code: kittingCode || `KIT-${Date.now()}`,
        delivery_status: 'pending'
      })
      .select()
      .single();

    if (routeError) {
      console.error('Error creating delivery route:', routeError);
      return serverError(res, 'Failed to create delivery route');
    }

    // Add route items if provided
    if (items.length > 0) {
      const itemsToInsert = items.map((item: any) => ({
        delivery_route_id: routeData.id,
        machine_id: item.machine_id,
        product_id: item.product_id,
        quantity_to_bring: item.quantity_to_bring || 0,
        quantity_to_remove: item.quantity_to_remove || 0
      }));

      const { error: itemsError } = await supabaseAdmin
        .from('delivery_route_items')
        .insert(itemsToInsert);

      if (itemsError) {
        console.error('Error adding route items:', itemsError);
      }
    }

    return successResponse(res, { delivery_route: routeData }, 201);
  } catch (err) {
    console.error('Error in create delivery route:', err);
    return serverError(res, 'Internal server error');
  }
});

// Update delivery route
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    const items = updateData.items;

    delete updateData.id;
    delete updateData.created_at;
    delete updateData.updated_at;
    delete updateData.kitting_code;
    delete updateData.items;

    const { data, error } = await supabaseAdmin
      .from('delivery_routes')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Delivery route not found');
      }
      console.error('Error updating delivery route:', error);
      return serverError(res, 'Failed to update delivery route');
    }

    // Update items if provided
    if (items && Array.isArray(items)) {
      await supabaseAdmin
        .from('delivery_route_items')
        .delete()
        .eq('delivery_route_id', id);

      if (items.length > 0) {
        const itemsToInsert = items.map((item: any) => ({
          delivery_route_id: id,
          machine_id: item.machine_id,
          product_id: item.product_id,
          quantity_to_bring: item.quantity_to_bring || 0,
          quantity_to_remove: item.quantity_to_remove || 0
        }));

        await supabaseAdmin
          .from('delivery_route_items')
          .insert(itemsToInsert);
      }
    }

    return successResponse(res, { delivery_route: data });
  } catch (err) {
    console.error('Error in update delivery route:', err);
    return serverError(res, 'Internal server error');
  }
});

// Start delivery route (change status to in_route)
router.post('/:id/start', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('delivery_routes')
      .update({
        delivery_status: 'in_route',
        started_at: new Date().toISOString()
      })
      .eq('id', id)
      .eq('delivery_status', 'pending')
      .select()
      .single();

    if (error) {
      console.error('Error starting route:', error);
      return serverError(res, 'Failed to start delivery route');
    }

    return successResponse(res, { delivery_route: data });
  } catch (err) {
    console.error('Error in start route:', err);
    return serverError(res, 'Internal server error');
  }
});

// Refill machine slot (deduct from warehouse inventory)
router.post('/:id/refill', requireAuth, async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { refills } = req.body; // Array of { slot_id, vending_machine_id, product_id, quantity, warehouse_inventory_id }

    console.log('🚀 [REFILL] Starting refill process for route:', id);
    console.log('📦 [REFILL] Refill data:', JSON.stringify(refills, null, 2));

    if (!refills || !Array.isArray(refills) || refills.length === 0) {
      console.error('❌ [REFILL] No refill data provided');
      return badRequest(res, 'Refill data is required');
    }

    // Get route details
    const { data: routeData, error: routeError } = await supabaseAdmin
      .from('delivery_routes')
      .select('*, warehouses (id, name)')
      .eq('id', id)
      .single();

    if (routeError || !routeData) {
      console.error('❌ [REFILL] Route not found:', routeError);
      return notFound(res, 'Delivery route not found');
    }

    console.log('📋 [REFILL] Route found:', routeData.name, 'Warehouse:', routeData.warehouse_id);

    const refillRecords = [];
    const inventoryUpdates = [];

    for (const refill of refills) {
      const {
        slot_id,
        vending_machine_id,
        product_id,
        quantity,
        warehouse_inventory_id,
        batch_number,
        expiry_date
      } = refill;

      console.log(`\n📦 [REFILL] Processing refill:`, {
        slot_id,
        product_id,
        quantity,
        warehouse_inventory_id
      });

      if (!slot_id || !vending_machine_id || !product_id || !quantity) {
        console.error('❌ [REFILL] Missing required fields, skipping:', {
          has_slot_id: !!slot_id,
          has_vending_machine_id: !!vending_machine_id,
          has_product_id: !!product_id,
          has_quantity: !!quantity,
          slot_id,
          vending_machine_id,
          product_id,
          quantity
        });
        continue;
      }

      // Get current slot quantity
      const { data: slotData, error: slotError } = await supabaseAdmin
        .from('slots')
        .select('quantity, max_capacity')
        .eq('id', slot_id)
        .single();

      if (slotError || !slotData) {
        console.error('❌ [REFILL] Slot not found:', slot_id, slotError);
        continue;
      }

      const oldQuantity = slotData.quantity;
      const newQuantity = oldQuantity + quantity;

      console.log(`📊 [REFILL] Slot update: ${oldQuantity} → ${newQuantity}`);

      // Update slot quantity
      const { error: slotUpdateError} = await supabaseAdmin
        .from('slots')
        .update({
          quantity: newQuantity,
          product_id: product_id
        })
        .eq('id', slot_id);

      if (slotUpdateError) {
        console.error('❌ [REFILL] Failed to update slot:', slotUpdateError);
        continue;
      }
      console.log('✅ [REFILL] Slot updated successfully');

      // Deduct from warehouse stock if inventory_id provided
      if (warehouse_inventory_id) {
        console.log('🏢 [REFILL] Deducting from warehouse stock:', warehouse_inventory_id);

        const { data: stockData, error: stockFetchError } = await supabaseAdmin
          .from('warehouse_stock')
          .select('quantity, batch_number, expiry_date')
          .eq('id', warehouse_inventory_id)
          .single();

        if (stockFetchError) {
          console.error('❌ [REFILL] Failed to fetch warehouse stock:', stockFetchError);
        } else if (stockData) {
          console.log(`📊 [REFILL] Current warehouse stock: ${stockData.quantity}`);

          if (stockData.quantity >= quantity) {
            const newStockQty = stockData.quantity - quantity;
            console.log(`📊 [REFILL] New warehouse stock: ${newStockQty}`);

            const { error: stockUpdateError } = await supabaseAdmin
              .from('warehouse_stock')
              .update({ quantity: newStockQty })
              .eq('id', warehouse_inventory_id);

            if (stockUpdateError) {
              console.error('❌ [REFILL] Failed to update warehouse stock:', stockUpdateError);
            } else {
              console.log('✅ [REFILL] Warehouse stock updated successfully');
              inventoryUpdates.push({
                product_id,
                old_quantity: stockData.quantity,
                new_quantity: newStockQty
              });

              // Record inventory transaction
              const { error: transError } = await supabaseAdmin
                .from('inventory_transactions')
                .insert({
                  warehouse_id: routeData.warehouse_id,
                  product_id,
                  transaction_type: 'machine_refill',
                  quantity_change: -quantity,
                  quantity_before: stockData.quantity,
                  quantity_after: newStockQty,
                  reference_type: 'delivery_route',
                  reference_id: id,
                  batch_number: stockData.batch_number || batch_number,
                  expiry_date: stockData.expiry_date || expiry_date,
                  notes: `Refilled machine slot ${slot_id}`,
                  created_by: req.user?.id
                });

              if (transError) {
                console.error('❌ [REFILL] Failed to record transaction:', transError);
              } else {
                console.log('✅ [REFILL] Transaction recorded');
              }
            }
          } else {
            console.error(`❌ [REFILL] Insufficient stock: ${stockData.quantity} < ${quantity}`);
          }
        } else {
          console.error('❌ [REFILL] Warehouse stock not found');
        }
      } else {
        console.warn('⚠️ [REFILL] No warehouse_inventory_id provided, skipping inventory deduction');
      }

      // Create refill record
      const { data: refillRecord, error: refillError } = await supabaseAdmin
        .from('machine_refill_records')
        .insert({
          delivery_route_id: id,
          vending_machine_id,
          warehouse_id: routeData.warehouse_id,
          slot_id,
          product_id,
          quantity_added: quantity,
          quantity_removed: 0,
          old_quantity: oldQuantity,
          new_quantity: newQuantity,
          batch_number,
          expiry_date,
          refilled_by: req.user?.id,
          refilled_at: new Date().toISOString()
        })
        .select()
        .single();

      if (refillError) {
        console.error('❌ [REFILL] Failed to create refill record:', refillError);
      } else if (refillRecord) {
        console.log('✅ [REFILL] Refill record created');
        refillRecords.push(refillRecord);
      }
    }

    console.log(`🎉 [REFILL] Completed: ${refillRecords.length} slots refilled, ${inventoryUpdates.length} inventory updates\n`);

    return successResponse(res, {
      refill_records: refillRecords,
      inventory_updates: inventoryUpdates,
      message: `${refillRecords.length} slots refilled successfully`
    });
  } catch (err) {
    console.error('❌ [REFILL] Error in refill machine:', err);
    return serverError(res, 'Internal server error');
  }
});

// Complete delivery route
router.post('/:id/complete', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('delivery_routes')
      .update({
        delivery_status: 'completed',
        completed_at: new Date().toISOString()
      })
      .eq('id', id)
      .eq('delivery_status', 'in_route')
      .select()
      .single();

    if (error) {
      console.error('Error completing route:', error);
      return serverError(res, 'Failed to complete delivery route');
    }

    return successResponse(res, { delivery_route: data });
  } catch (err) {
    console.error('Error in complete route:', err);
    return serverError(res, 'Internal server error');
  }
});

// Cancel delivery route
router.post('/:id/cancel', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('delivery_routes')
      .update({ delivery_status: 'cancelled' })
      .eq('id', id)
      .neq('delivery_status', 'completed')
      .select()
      .single();

    if (error) {
      console.error('Error cancelling route:', error);
      return serverError(res, 'Failed to cancel delivery route');
    }

    return successResponse(res, { delivery_route: data });
  } catch (err) {
    console.error('Error in cancel route:', err);
    return serverError(res, 'Internal server error');
  }
});

// Delete delivery route (only pending)
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabaseAdmin
      .from('delivery_routes')
      .delete()
      .eq('id', id)
      .eq('delivery_status', 'pending');

    if (error) {
      console.error('Error deleting delivery route:', error);
      return serverError(res, 'Failed to delete delivery route. Only pending routes can be deleted.');
    }

    return successResponse(res, { message: 'Delivery route deleted successfully' });
  } catch (err) {
    console.error('Error in delete delivery route:', err);
    return serverError(res, 'Internal server error');
  }
});

export default router;
