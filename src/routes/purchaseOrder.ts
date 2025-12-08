import { Router, type Request } from 'express';
import { supabaseAdmin } from '../supabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { badRequest, serverError, successResponse, notFound } from '../utils/responses.js';

const router = Router();

// Get all purchase orders
router.get('/', requireAuth, async (req, res) => {
  try {
    const { status, supplier_id, search, limit = 50, offset = 0 } = req.query;

    let query = supabaseAdmin
      .from('purchase_orders')
      .select(`
        *,
        suppliers (id, company_name),
        warehouses (id, name)
      `, { count: 'exact' });

    if (status && typeof status === 'string') {
      query = query.eq('status', status);
    }

    if (supplier_id && typeof supplier_id === 'string') {
      query = query.eq('supplier_id', supplier_id);
    }

    if (search && typeof search === 'string') {
      query = query.or(`reference.ilike.%${search}%,buyer_name.ilike.%${search}%`);
    }

    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(Number(offset), Number(offset) + Number(limit) - 1);

    if (error) {
      console.error('Error fetching purchase orders:', error);
      return serverError(res, 'Failed to fetch purchase orders');
    }

    return successResponse(res, { purchase_orders: data, total: count });
  } catch (err) {
    console.error('Error in get purchase orders:', err);
    return serverError(res, 'Internal server error');
  }
});

// Get single purchase order with items
router.get('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    // First, get the purchase order with suppliers and warehouses
    const { data: poData, error: poError } = await supabaseAdmin
      .from('purchase_orders')
      .select(`
        *,
        suppliers (id, company_name, email, phone_number),
        warehouses (id, name, address)
      `)
      .eq('id', id)
      .single();

    if (poError) {
      if (poError.code === 'PGRST116') {
        return notFound(res, 'Purchase order not found');
      }
      console.error('Error fetching purchase order:', poError);
      return serverError(res, 'Failed to fetch purchase order');
    }

    // Get purchase order items separately
    console.log('Fetching items for PO:', id);
    const { data: itemsData, error: itemsError } = await supabaseAdmin
      .from('purchase_order_items')
      .select('*')
      .eq('purchase_order_id', id);

    console.log('Items query result:', { itemsData, itemsError });

    if (itemsError) {
      console.error('Error fetching purchase order items:', itemsError);
    }

    // Get product details for each item
    const items = itemsData || [];
    if (items.length > 0) {
      const productIds = [...new Set(items.map((item: any) => item.product_id))];

      // Fetch all product fields to handle different column naming conventions
      const { data: productsData, error: productsError } = await supabaseAdmin
        .from('products')
        .select('*')
        .in('id', productIds);

      if (productsError) {
        console.error('Error fetching products:', productsError);
      }

      if (!productsError && productsData) {
        const productsMap = new Map(productsData.map((p: any) => [p.id, p]));

        // Attach product info to each item
        items.forEach((item: any) => {
          item.products = productsMap.get(item.product_id) || null;
        });
      }
    }

    // Combine the data
    const result = {
      ...poData,
      purchase_order_items: items
    };

    return successResponse(res, { purchase_order: result });
  } catch (err) {
    console.error('Error in get purchase order:', err);
    return serverError(res, 'Internal server error');
  }
});

// Create purchase order
router.post('/', requireAuth, async (req: Request, res) => {
  try {
    const {
      supplier_id,
      vendor_reference,
      buyer_name,
      delivery_address,
      currency = 'KWD',
      order_deadline,
      expected_arrival,
      deliver_to_warehouse_id,
      terms_and_conditions,
      source_document,
      items = []
    } = req.body;

    // Generate reference
    const { data: refData, error: refError } = await supabaseAdmin
      .rpc('generate_po_reference');

    if (refError) {
      console.error('Error generating reference:', refError);
      return serverError(res, 'Failed to generate PO reference');
    }

    const reference = refData;

    // Calculate total
    const totalAmount = items.reduce((sum: number, item: any) => {
      return sum + (item.quantity * item.unit_price);
    }, 0);

    // Create PO
    const { data: poData, error: poError } = await supabaseAdmin
      .from('purchase_orders')
      .insert({
        reference,
        supplier_id,
        vendor_reference,
        buyer_name,
        delivery_address,
        currency,
        order_deadline,
        expected_arrival,
        deliver_to_warehouse_id,
        total_amount: totalAmount,
        terms_and_conditions,
        source_document,
        created_by: req.user?.id
      })
      .select()
      .single();

    if (poError) {
      console.error('Error creating purchase order:', poError);
      return serverError(res, 'Failed to create purchase order');
    }

    // Add items
    if (items.length > 0) {
      // subtotal is a GENERATED column - do not include it in insert
      const itemsToInsert = items.map((item: any) => ({
        purchase_order_id: poData.id,
        product_id: item.product_id,
        quantity: item.quantity,
        unit_price: item.unit_price
      }));

      console.log('Inserting PO items:', JSON.stringify(itemsToInsert, null, 2));

      const { data: insertedItems, error: itemsError } = await supabaseAdmin
        .from('purchase_order_items')
        .insert(itemsToInsert)
        .select();

      if (itemsError) {
        console.error('Error adding PO items:', itemsError);
        // Return error info to help debug
        return serverError(res, `PO created but items failed: ${itemsError.message}`);
      }

      console.log('Successfully inserted PO items:', insertedItems?.length);
    }

    return successResponse(res, { purchase_order: poData, reference }, 201);
  } catch (err) {
    console.error('Error in create purchase order:', err);
    return serverError(res, 'Internal server error');
  }
});

// Update purchase order
router.put('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    const items = updateData.items;

    delete updateData.id;
    delete updateData.created_at;
    delete updateData.updated_at;
    delete updateData.reference;
    delete updateData.items;

    // Recalculate total if items provided
    if (items && Array.isArray(items)) {
      updateData.total_amount = items.reduce((sum: number, item: any) => {
        return sum + (item.quantity * item.unit_price);
      }, 0);
    }

    const { data, error } = await supabaseAdmin
      .from('purchase_orders')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return notFound(res, 'Purchase order not found');
      }
      console.error('Error updating purchase order:', error);
      return serverError(res, 'Failed to update purchase order');
    }

    // Update items if provided
    if (items && Array.isArray(items)) {
      // Delete existing items
      await supabaseAdmin
        .from('purchase_order_items')
        .delete()
        .eq('purchase_order_id', id);

      // Insert new items (subtotal is GENERATED - don't include it)
      if (items.length > 0) {
        const itemsToInsert = items.map((item: any) => ({
          purchase_order_id: id,
          product_id: item.product_id,
          quantity: item.quantity,
          unit_price: item.unit_price
        }));

        await supabaseAdmin
          .from('purchase_order_items')
          .insert(itemsToInsert);
      }
    }

    return successResponse(res, { purchase_order: data });
  } catch (err) {
    console.error('Error in update purchase order:', err);
    return serverError(res, 'Internal server error');
  }
});

// Confirm/Lock purchase order
router.post('/:id/confirm', requireAuth, async (req: Request, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('purchase_orders')
      .update({
        status: 'locked',
        confirmed_by: req.user?.id,
        confirmation_date: new Date().toISOString()
      })
      .eq('id', id)
      .eq('status', 'draft')
      .select()
      .single();

    if (error) {
      console.error('Error confirming PO:', error);
      return serverError(res, 'Failed to confirm purchase order');
    }

    return successResponse(res, { purchase_order: data });
  } catch (err) {
    console.error('Error in confirm PO:', err);
    return serverError(res, 'Internal server error');
  }
});

// Send purchase order to supplier
router.post('/:id/send', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('purchase_orders')
      .update({ status: 'sent' })
      .eq('id', id)
      .in('status', ['draft', 'locked'])
      .select()
      .single();

    if (error) {
      console.error('Error sending PO:', error);
      return serverError(res, 'Failed to send purchase order');
    }

    // TODO: Integrate with email service to actually send to supplier

    return successResponse(res, { purchase_order: data, message: 'Purchase order sent' });
  } catch (err) {
    console.error('Error in send PO:', err);
    return serverError(res, 'Internal server error');
  }
});

// Confirm delivery (Purchase Confirmation module - Delivery In)
router.post('/confirm-delivery', requireAuth, async (req: Request, res) => {
  try {
    const {
      purchase_order_id,
      warehouse_id,
      received_items,
      confirmation_notes
    } = req.body;

    if (!purchase_order_id || !received_items || !Array.isArray(received_items)) {
      return badRequest(res, 'Invalid request data');
    }

    // Get PO details
    const { data: poData, error: poError } = await supabaseAdmin
      .from('purchase_orders')
      .select('*')
      .eq('id', purchase_order_id)
      .single();

    if (poError || !poData) {
      return notFound(res, 'Purchase order not found');
    }

    if (poData.status === 'received') {
      return badRequest(res, 'Purchase order already received');
    }

    const targetWarehouse = warehouse_id || poData.deliver_to_warehouse_id;

    if (!targetWarehouse) {
      return badRequest(res, 'No destination warehouse specified');
    }

    // Process each received item
    for (const item of received_items) {
      const {
        product_id,
        ordered_quantity,
        received_quantity,
        discrepancy_notes,
        purchase_order_item_id
      } = item;

      // Get current warehouse stock
      const { data: existingStock } = await supabaseAdmin
        .from('warehouse_stock')
        .select('id, quantity')
        .eq('warehouse_id', targetWarehouse)
        .eq('product_id', product_id)
        .maybeSingle();

      const quantityBefore = existingStock?.quantity || 0;
      const quantityAfter = quantityBefore + received_quantity;

      if (existingStock) {
        // Update existing stock
        await supabaseAdmin
          .from('warehouse_stock')
          .update({
            quantity: quantityAfter,
            last_purchase_date: new Date().toISOString().split('T')[0]
          })
          .eq('id', existingStock.id);
      } else {
        // Create new warehouse stock entry
        await supabaseAdmin
          .from('warehouse_stock')
          .insert({
            warehouse_id: targetWarehouse,
            product_id: product_id,
            quantity: received_quantity,
            last_purchase_date: new Date().toISOString().split('T')[0]
          });
      }

      // Record inventory transaction
      await supabaseAdmin
        .from('inventory_transactions')
        .insert({
          warehouse_id: targetWarehouse,
          product_id: product_id,
          transaction_type: 'purchase_receipt',
          quantity_change: received_quantity,
          quantity_before: quantityBefore,
          quantity_after: quantityAfter,
          reference_type: 'purchase_order',
          reference_id: purchase_order_id,
          notes: discrepancy_notes || confirmation_notes || `Received from PO ${poData.reference}`,
          created_by: req.user?.id
        });

      // Update received quantity in PO item
      if (purchase_order_item_id) {
        await supabaseAdmin
          .from('purchase_order_items')
          .update({
            received_quantity: received_quantity,
            notes: discrepancy_notes || null
          })
          .eq('id', purchase_order_item_id);
      }
    }

    // Update PO status to received
    const { data: updatedPO, error: updateError } = await supabaseAdmin
      .from('purchase_orders')
      .update({
        status: 'received',
        confirmed_by: req.user?.id,
        confirmation_date: new Date().toISOString()
      })
      .eq('id', purchase_order_id)
      .select()
      .single();

    if (updateError) {
      console.error('Error updating PO status:', updateError);
      return serverError(res, 'Failed to update purchase order status');
    }

    return successResponse(res, {
      purchase_order: updatedPO,
      message: 'Delivery confirmed and inventory updated successfully'
    });
  } catch (err) {
    console.error('Error in confirm delivery:', err);
    return serverError(res, 'Internal server error');
  }
});

// Receive goods (mark PO as received and update inventory)
router.post('/:id/receive', requireAuth, async (req: Request, res) => {
  try {
    const { id } = req.params;
    const {
      received_items,
      batch_number,
      expiry_date,
      manufacturing_date,
      notes
    } = req.body;

    // Get PO details
    const { data: poData, error: poError } = await supabaseAdmin
      .from('purchase_orders')
      .select('*, purchase_order_items (*)')
      .eq('id', id)
      .single();

    if (poError || !poData) {
      return notFound(res, 'Purchase order not found');
    }

    if (poData.status === 'received') {
      return badRequest(res, 'Purchase order already received');
    }

    if (!poData.deliver_to_warehouse_id) {
      return badRequest(res, 'No destination warehouse specified');
    }

    // Update inventory for each item
    const itemsToReceive = received_items || poData.purchase_order_items;

    for (const item of itemsToReceive) {
      const receivedQty = item.received_quantity || item.quantity;

      // Check if stock exists for this product and batch
      const { data: existingStock } = await supabaseAdmin
        .from('warehouse_stock')
        .select('quantity')
        .eq('warehouse_id', poData.deliver_to_warehouse_id)
        .eq('product_id', item.product_id)
        .eq('batch_number', item.batch_number || batch_number || '')
        .single();

      if (existingStock) {
        // Update existing stock
        await supabaseAdmin
          .from('warehouse_stock')
          .update({
            quantity: existingStock.quantity + receivedQty,
            last_purchase_date: new Date().toISOString().split('T')[0],
            last_purchase_price: item.unit_price
          })
          .eq('warehouse_id', poData.deliver_to_warehouse_id)
          .eq('product_id', item.product_id)
          .eq('batch_number', item.batch_number || batch_number || '');
      } else {
        // Add new warehouse stock
        await supabaseAdmin
          .from('warehouse_stock')
          .insert({
            warehouse_id: poData.deliver_to_warehouse_id,
            product_id: item.product_id,
            quantity: receivedQty,
            expiry_date: item.expiry_date || expiry_date,
            batch_number: item.batch_number || batch_number,
            unit_cost: item.unit_price,
            last_purchase_date: new Date().toISOString().split('T')[0],
            last_purchase_price: item.unit_price
          });
      }

      // Record inventory transaction
      await supabaseAdmin
        .from('inventory_transactions')
        .insert({
          warehouse_id: poData.deliver_to_warehouse_id,
          product_id: item.product_id,
          transaction_type: 'purchase_receipt',
          quantity_change: receivedQty,
          quantity_before: 0,
          quantity_after: receivedQty,
          reference_type: 'purchase_order',
          reference_id: id,
          batch_number: item.batch_number || batch_number,
          expiry_date: item.expiry_date || expiry_date,
          notes: `Received from PO ${poData.reference}`,
          created_by: req.user?.id
        });

      // Update received quantity in PO item
      await supabaseAdmin
        .from('purchase_order_items')
        .update({ received_quantity: receivedQty })
        .eq('id', item.id);
    }

    // Update PO status
    const { data: updatedPO, error: updateError } = await supabaseAdmin
      .from('purchase_orders')
      .update({ status: 'received' })
      .eq('id', id)
      .select()
      .single();

    if (updateError) {
      console.error('Error updating PO status:', updateError);
    }

    return successResponse(res, {
      purchase_order: updatedPO,
      message: 'Goods received and inventory updated'
    });
  } catch (err) {
    console.error('Error in receive goods:', err);
    return serverError(res, 'Internal server error');
  }
});

// Cancel purchase order
router.post('/:id/cancel', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from('purchase_orders')
      .update({ status: 'cancelled' })
      .eq('id', id)
      .neq('status', 'received')
      .select()
      .single();

    if (error) {
      console.error('Error cancelling PO:', error);
      return serverError(res, 'Failed to cancel purchase order');
    }

    return successResponse(res, { purchase_order: data });
  } catch (err) {
    console.error('Error in cancel PO:', err);
    return serverError(res, 'Internal server error');
  }
});

// Delete purchase order (only drafts)
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabaseAdmin
      .from('purchase_orders')
      .delete()
      .eq('id', id)
      .eq('status', 'draft');

    if (error) {
      console.error('Error deleting purchase order:', error);
      return serverError(res, 'Failed to delete purchase order. Only draft orders can be deleted.');
    }

    return successResponse(res, { message: 'Purchase order deleted successfully' });
  } catch (err) {
    console.error('Error in delete purchase order:', err);
    return serverError(res, 'Internal server error');
  }
});

export default router;
