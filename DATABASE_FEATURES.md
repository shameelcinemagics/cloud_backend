# Database Features Reference

## 📊 Helper Views

### 1. Low Stock Items
Shows all products currently below their minimum stock level.

```sql
SELECT * FROM public.low_stock_items;
```

**Columns:**
- `id` - Warehouse stock ID
- `warehouse_id` - Warehouse UUID
- `warehouse_name` - Warehouse name
- `product_id` - Product UUID
- `quantity` - Current quantity
- `min_stock_level` - Minimum stock threshold
- `max_stock_level` - Maximum stock capacity
- `shortage` - How many units below minimum
- `last_purchase_date` - Last time this product was purchased
- `last_purchase_price` - Last purchase price

**Use Case:** Generate reorder reports, low stock alerts

---

### 2. Expiring Products
Shows products that will expire within the next 30 days.

```sql
SELECT * FROM public.expiring_products;
```

**Columns:**
- `id` - Warehouse stock ID
- `warehouse_id` - Warehouse UUID
- `warehouse_name` - Warehouse name
- `product_id` - Product UUID
- `quantity` - Quantity on hand
- `expiry_date` - Expiration date
- `batch_number` - Batch number
- `days_until_expiry` - Days until expiration

**Use Case:** Prevent waste, plan promotions, rotate stock

---

### 3. Purchase Orders Summary
Purchase orders with supplier and warehouse details joined.

```sql
SELECT * FROM public.purchase_orders_summary
WHERE status = 'locked'
ORDER BY expected_arrival;
```

**Columns:**
- `id`, `reference`, `status` - Basic PO info
- `supplier_id`, `supplier_name`, `supplier_email`, `supplier_phone` - Supplier details
- `total_amount`, `currency` - Financial info
- `expected_arrival` - Expected delivery date
- `warehouse_id`, `warehouse_name` - Destination warehouse
- `item_count` - Number of different products
- `total_items` - Total quantity of all items

**Use Case:** Purchase order dashboard, supplier communication

---

### 4. Delivery Routes Summary
Delivery routes with aggregated statistics.

```sql
SELECT * FROM public.delivery_routes_summary
WHERE delivery_status = 'in_route'
ORDER BY route_date DESC;
```

**Columns:**
- `id`, `name`, `delivery_status`, `route_date` - Basic route info
- `warehouse_id`, `warehouse_name` - Source warehouse
- `person_in_charge_id` - Assigned person
- `kitting_code` - Unique route code
- `started_at`, `completed_at`, `duration_hours` - Timing info
- `item_count` - Number of items on route
- `total_quantity_to_bring` - Total items to deliver
- `total_quantity_to_remove` - Total items to collect

**Use Case:** Route tracking, performance metrics, scheduling

---

## 🔧 Helper Functions

### 1. Get Product Stock Level
Returns total stock quantity for a product in a warehouse.

```sql
SELECT public.get_product_stock_level(
  'f47ac10b-58cc-4372-a567-0e02b2c3d479'::uuid,  -- warehouse_id
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid   -- product_id
);
```

**Returns:** `INTEGER` - Total quantity in stock

**Use Case:** Real-time stock checks, availability verification

---

### 2. Check Reorder Needed
Checks if a product needs to be reordered (at or below minimum level).

```sql
SELECT public.check_reorder_needed(
  'f47ac10b-58cc-4372-a567-0e02b2c3d479'::uuid,  -- warehouse_id
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid   -- product_id
);
```

**Returns:** `BOOLEAN` - `true` if reorder needed, `false` otherwise

**Use Case:** Automated reorder triggers, stock alerts

---

### 3. Get Warehouse Utilization
Returns warehouse capacity utilization as a percentage.

```sql
SELECT public.get_warehouse_utilization(
  'f47ac10b-58cc-4372-a567-0e02b2c3d479'::uuid  -- warehouse_id
);
```

**Returns:** `NUMERIC` - Percentage (0-100) of warehouse capacity used

**Use Case:** Capacity planning, warehouse efficiency metrics

---

## 🎯 Example Queries

### Find Products to Reorder
```sql
SELECT
  ws.product_id,
  w.name AS warehouse,
  ws.quantity AS current_stock,
  ws.min_stock_level,
  ws.max_stock_level,
  ot.supplier_id
FROM public.warehouse_stock ws
JOIN public.warehouses w ON w.id = ws.warehouse_id
LEFT JOIN public.ordering_triggers ot
  ON ot.product_id = ws.product_id
  AND ot.warehouse_id = ws.warehouse_id
WHERE ws.quantity <= ws.min_stock_level
  AND ws.quantity >= 0
ORDER BY (ws.min_stock_level - ws.quantity) DESC;
```

### Active Purchase Orders by Supplier
```sql
SELECT
  s.company_name,
  COUNT(*) AS order_count,
  SUM(po.total_amount) AS total_value,
  po.currency
FROM public.purchase_orders po
JOIN public.suppliers s ON s.id = po.supplier_id
WHERE po.status IN ('locked', 'sent')
GROUP BY s.company_name, po.currency
ORDER BY total_value DESC;
```

### Delivery Route Performance
```sql
SELECT
  dr.name,
  dr.route_date,
  dr.delivery_status,
  EXTRACT(EPOCH FROM (dr.completed_at - dr.started_at))/3600 AS hours_taken,
  COUNT(dri.id) AS stops,
  SUM(dri.quantity_to_bring) AS items_delivered
FROM public.delivery_routes dr
LEFT JOIN public.delivery_route_items dri ON dri.delivery_route_id = dr.id
WHERE dr.delivery_status = 'completed'
  AND dr.route_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY dr.id, dr.name, dr.route_date, dr.delivery_status, dr.started_at, dr.completed_at
ORDER BY dr.route_date DESC;
```

### Stock Movement History
```sql
SELECT
  it.created_at,
  w.name AS warehouse,
  it.transaction_type,
  it.quantity_change,
  it.quantity_before,
  it.quantity_after,
  it.reference_type,
  it.notes
FROM public.inventory_transactions it
JOIN public.warehouses w ON w.id = it.warehouse_id
WHERE it.product_id = 'your-product-uuid'::uuid
ORDER BY it.created_at DESC
LIMIT 50;
```

### Warehouse Stock Value
```sql
SELECT
  w.name AS warehouse,
  COUNT(DISTINCT ws.product_id) AS unique_products,
  SUM(ws.quantity) AS total_items,
  SUM(ws.quantity * ws.unit_cost) AS total_value,
  ROUND(public.get_warehouse_utilization(w.id), 2) AS utilization_pct
FROM public.warehouses w
LEFT JOIN public.warehouse_stock ws ON ws.warehouse_id = w.id
GROUP BY w.id, w.name
ORDER BY total_value DESC;
```

---

## 🔔 Automated Triggers

### Inventory Transaction Tracking
Every time warehouse stock quantity changes, an inventory transaction is automatically created.

**Trigger:** `track_warehouse_stock_trigger`
**Function:** `track_warehouse_stock_changes()`
**Fires:** After INSERT or UPDATE on `warehouse_stock`

**What it tracks:**
- Initial stock entries
- Stock increases/decreases
- Before and after quantities
- Change amounts
- Batch numbers and expiry dates
- User who made the change

### Purchase Order Total Calculation
Automatically recalculates purchase order total when items are added/updated/removed.

**Trigger:** `update_po_total_on_item_change`
**Function:** `update_purchase_order_total()`
**Fires:** After INSERT, UPDATE, or DELETE on `purchase_order_items`

### Subtotal Calculation
Automatically calculates line item subtotal when quantity or unit price changes.

**Trigger:** `calculate_po_item_subtotal_trigger`
**Function:** `calculate_po_item_subtotal()`
**Fires:** Before INSERT or UPDATE on `purchase_order_items`

---

## 🔐 Security Notes

All views and functions:
- ✅ Respect Row Level Security (RLS) policies
- ✅ Only accessible to authenticated users
- ✅ Service role has full access for admin operations
- ✅ Audit trails maintained automatically

---

## 📈 Performance Tips

1. **Use Views for Dashboards**
   - Views are optimized and maintain consistent logic
   - Results are calculated on-the-fly

2. **Use Functions for Conditionals**
   - Functions are marked as STABLE for optimization
   - Cache results when possible in your application

3. **Index Usage**
   - All foreign keys are indexed
   - Common filter columns have indexes
   - Date ranges use optimized indexes

4. **Batch Operations**
   - Use transactions for multiple related changes
   - Consider bulk inserts for large data loads

---

## 🆘 Support Queries

### Check Index Usage
```sql
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan AS times_used,
  idx_tup_read AS tuples_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

### Find Slow Queries
```sql
-- Enable pg_stat_statements extension first
SELECT
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
WHERE query LIKE '%warehouse_stock%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Table Sizes
```sql
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```
