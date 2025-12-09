-- Migration: Production Optimization and Cleanup
-- Created: 2025-12-08
-- Description: Optimizes database for production, adds performance enhancements, and cleans up unnecessary data

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20251208114450', 'Production optimization - indexes, constraints, cleanup')
ON CONFLICT (version) DO NOTHING;

-- ============================================================================
-- 1. DATABASE CLEANUP
-- Remove any test or temporary data (if exists)
-- ============================================================================

-- Clean up any invalid or orphaned records
DELETE FROM public.user_page_perms WHERE user_id NOT IN (SELECT id FROM auth.users);
DELETE FROM public.user_roles WHERE user_id NOT IN (SELECT id FROM auth.users);

-- Clean up any invalid warehouse stock records with negative quantities
UPDATE public.warehouse_stock SET quantity = 0 WHERE quantity < 0;

-- ============================================================================
-- 2. ADD MISSING INDEXES FOR PERFORMANCE
-- ============================================================================

-- Indexes for auth relationships
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_created_by ON public.purchase_orders(created_by);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_confirmed_by ON public.purchase_orders(confirmed_by);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_person_warehouse ON public.delivery_routes(person_in_charge_id, warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_adjusted_by ON public.stock_adjustments(adjusted_by);
CREATE INDEX IF NOT EXISTS idx_grn_received_by ON public.goods_receipt_notes(received_by);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse_product ON public.warehouse_stock(warehouse_id, product_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_status_date ON public.delivery_routes(delivery_status, route_date);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status_supplier ON public.purchase_orders(status, supplier_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_warehouse_date ON public.stock_adjustments(warehouse_id, adjustment_date DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_transactions_warehouse_product ON public.inventory_transactions(warehouse_id, product_id);

-- Indexes for filtering and sorting
CREATE INDEX IF NOT EXISTS idx_suppliers_status_company ON public.suppliers(status, company_name);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_quantity_low ON public.warehouse_stock(quantity) WHERE quantity <= min_stock_level;
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_expiry_upcoming ON public.warehouse_stock(expiry_date) WHERE expiry_date IS NOT NULL AND expiry_date > CURRENT_DATE;

-- ============================================================================
-- 3. ADD CONSTRAINTS FOR DATA INTEGRITY
-- ============================================================================

-- Ensure email formats are valid in suppliers
ALTER TABLE public.suppliers
DROP CONSTRAINT IF EXISTS check_supplier_email_format;

ALTER TABLE public.suppliers
ADD CONSTRAINT check_supplier_email_format
CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Ensure phone numbers are not empty strings
ALTER TABLE public.suppliers
DROP CONSTRAINT IF EXISTS check_supplier_phone_not_empty;

ALTER TABLE public.suppliers
ADD CONSTRAINT check_supplier_phone_not_empty
CHECK (phone_number IS NULL OR LENGTH(TRIM(phone_number)) > 0);

-- Ensure warehouse stock levels are logical
ALTER TABLE public.warehouse_stock
DROP CONSTRAINT IF EXISTS check_stock_levels_logical;

ALTER TABLE public.warehouse_stock
ADD CONSTRAINT check_stock_levels_logical
CHECK (max_stock_level IS NULL OR max_stock_level >= min_stock_level);

-- Ensure purchase order amounts are non-negative
ALTER TABLE public.purchase_orders
DROP CONSTRAINT IF EXISTS check_po_total_non_negative;

ALTER TABLE public.purchase_orders
ADD CONSTRAINT check_po_total_non_negative
CHECK (total_amount >= 0);

-- Ensure delivery route dates are logical
ALTER TABLE public.delivery_routes
DROP CONSTRAINT IF EXISTS check_delivery_dates_logical;

ALTER TABLE public.delivery_routes
ADD CONSTRAINT check_delivery_dates_logical
CHECK (
  (started_at IS NULL OR completed_at IS NULL OR started_at <= completed_at)
  AND (route_date <= CURRENT_DATE + INTERVAL '30 days')
);

-- ============================================================================
-- 4. ADD HELPER VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Low stock items per warehouse
CREATE OR REPLACE VIEW public.low_stock_items AS
SELECT
  ws.id,
  ws.warehouse_id,
  w.name AS warehouse_name,
  ws.product_id,
  ws.quantity,
  ws.min_stock_level,
  ws.max_stock_level,
  (ws.min_stock_level - ws.quantity) AS shortage,
  ws.last_purchase_date,
  ws.last_purchase_price
FROM public.warehouse_stock ws
JOIN public.warehouses w ON w.id = ws.warehouse_id
WHERE ws.quantity <= ws.min_stock_level
ORDER BY (ws.min_stock_level - ws.quantity) DESC;

-- View: Expiring products (within 30 days)
CREATE OR REPLACE VIEW public.expiring_products AS
SELECT
  ws.id,
  ws.warehouse_id,
  w.name AS warehouse_name,
  ws.product_id,
  ws.quantity,
  ws.expiry_date,
  ws.batch_number,
  (ws.expiry_date - CURRENT_DATE) AS days_until_expiry
FROM public.warehouse_stock ws
JOIN public.warehouses w ON w.id = ws.warehouse_id
WHERE ws.expiry_date IS NOT NULL
  AND ws.expiry_date > CURRENT_DATE
  AND ws.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY ws.expiry_date ASC;

-- View: Purchase order summary with supplier details
CREATE OR REPLACE VIEW public.purchase_orders_summary AS
SELECT
  po.id,
  po.reference,
  po.status,
  po.supplier_id,
  s.company_name AS supplier_name,
  s.email AS supplier_email,
  s.phone_number AS supplier_phone,
  po.total_amount,
  po.currency,
  po.expected_arrival,
  po.deliver_to_warehouse_id,
  w.name AS warehouse_name,
  po.created_at,
  po.created_by,
  po.confirmation_date,
  (SELECT COUNT(*) FROM public.purchase_order_items WHERE purchase_order_id = po.id) AS item_count,
  (SELECT SUM(quantity) FROM public.purchase_order_items WHERE purchase_order_id = po.id) AS total_items
FROM public.purchase_orders po
LEFT JOIN public.suppliers s ON s.id = po.supplier_id
LEFT JOIN public.warehouses w ON w.id = po.deliver_to_warehouse_id;

-- View: Delivery route status with details
CREATE OR REPLACE VIEW public.delivery_routes_summary AS
SELECT
  dr.id,
  dr.name,
  dr.delivery_status,
  dr.route_date,
  dr.warehouse_id,
  w.name AS warehouse_name,
  dr.person_in_charge_id,
  dr.kitting_code,
  dr.started_at,
  dr.completed_at,
  EXTRACT(EPOCH FROM (dr.completed_at - dr.started_at))/3600 AS duration_hours,
  (SELECT COUNT(*) FROM public.delivery_route_items WHERE delivery_route_id = dr.id) AS item_count,
  (SELECT SUM(quantity_to_bring) FROM public.delivery_route_items WHERE delivery_route_id = dr.id) AS total_quantity_to_bring,
  (SELECT SUM(quantity_to_remove) FROM public.delivery_route_items WHERE delivery_route_id = dr.id) AS total_quantity_to_remove
FROM public.delivery_routes dr
LEFT JOIN public.warehouses w ON w.id = dr.warehouse_id;

-- ============================================================================
-- 5. ADD HELPER FUNCTIONS
-- ============================================================================

-- Function: Get current stock level for a product in a warehouse
CREATE OR REPLACE FUNCTION public.get_product_stock_level(
  p_warehouse_id UUID,
  p_product_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  stock_level INTEGER;
BEGIN
  SELECT COALESCE(SUM(quantity), 0)
  INTO stock_level
  FROM public.warehouse_stock
  WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;

  RETURN stock_level;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Check if reorder is needed for a product
CREATE OR REPLACE FUNCTION public.check_reorder_needed(
  p_warehouse_id UUID,
  p_product_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  current_stock INTEGER;
  min_level INTEGER;
BEGIN
  SELECT quantity, min_stock_level
  INTO current_stock, min_level
  FROM public.warehouse_stock
  WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id
  LIMIT 1;

  RETURN (current_stock IS NOT NULL AND min_level IS NOT NULL AND current_stock <= min_level);
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get warehouse utilization percentage
CREATE OR REPLACE FUNCTION public.get_warehouse_utilization(p_warehouse_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  total_stock INTEGER;
  total_capacity INTEGER;
BEGIN
  SELECT
    COALESCE(SUM(quantity), 0),
    COALESCE(SUM(max_stock_level), 0)
  INTO total_stock, total_capacity
  FROM public.warehouse_stock
  WHERE warehouse_id = p_warehouse_id;

  IF total_capacity = 0 THEN
    RETURN 0;
  END IF;

  RETURN ROUND((total_stock::NUMERIC / total_capacity::NUMERIC) * 100, 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- 6. ADD TRIGGERS FOR AUTOMATIC INVENTORY TRACKING
-- ============================================================================

-- Function: Auto-create inventory transaction on warehouse stock change
CREATE OR REPLACE FUNCTION public.track_warehouse_stock_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Only track if quantity actually changed
  IF (TG_OP = 'UPDATE' AND OLD.quantity = NEW.quantity) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.inventory_transactions (
      warehouse_id,
      product_id,
      transaction_type,
      quantity_change,
      quantity_before,
      quantity_after,
      reference_type,
      batch_number,
      expiry_date,
      notes,
      created_by
    ) VALUES (
      NEW.warehouse_id,
      NEW.product_id,
      'adjustment',
      NEW.quantity,
      0,
      NEW.quantity,
      'initial_stock',
      NEW.batch_number,
      NEW.expiry_date,
      'Initial stock entry',
      auth.uid()
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.inventory_transactions (
      warehouse_id,
      product_id,
      transaction_type,
      quantity_change,
      quantity_before,
      quantity_after,
      reference_type,
      batch_number,
      expiry_date,
      notes,
      created_by
    ) VALUES (
      NEW.warehouse_id,
      NEW.product_id,
      'adjustment',
      NEW.quantity - OLD.quantity,
      OLD.quantity,
      NEW.quantity,
      'stock_update',
      NEW.batch_number,
      NEW.expiry_date,
      'Stock quantity updated',
      auth.uid()
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS track_warehouse_stock_trigger ON public.warehouse_stock;
CREATE TRIGGER track_warehouse_stock_trigger
  AFTER INSERT OR UPDATE OF quantity ON public.warehouse_stock
  FOR EACH ROW
  EXECUTE FUNCTION public.track_warehouse_stock_changes();

-- ============================================================================
-- 7. GRANT PERMISSIONS FOR NEW OBJECTS
-- ============================================================================

-- Grant execute on new functions
GRANT EXECUTE ON FUNCTION public.get_product_stock_level(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_reorder_needed(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_warehouse_utilization(UUID) TO authenticated;

-- Grant select on views
GRANT SELECT ON public.low_stock_items TO authenticated;
GRANT SELECT ON public.expiring_products TO authenticated;
GRANT SELECT ON public.purchase_orders_summary TO authenticated;
GRANT SELECT ON public.delivery_routes_summary TO authenticated;

-- ============================================================================
-- 8. ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON VIEW public.low_stock_items IS 'Shows all products below minimum stock level';
COMMENT ON VIEW public.expiring_products IS 'Shows products expiring within 30 days';
COMMENT ON VIEW public.purchase_orders_summary IS 'Purchase orders with supplier and warehouse details';
COMMENT ON VIEW public.delivery_routes_summary IS 'Delivery routes with aggregated statistics';
COMMENT ON FUNCTION public.get_product_stock_level(UUID, UUID) IS 'Returns total stock quantity for a product in a warehouse';
COMMENT ON FUNCTION public.check_reorder_needed(UUID, UUID) IS 'Returns true if product stock is at or below minimum level';
COMMENT ON FUNCTION public.get_warehouse_utilization(UUID) IS 'Returns warehouse capacity utilization as percentage';

-- ============================================================================
-- 9. VACUUM AND ANALYZE FOR OPTIMIZATION
-- ============================================================================

-- Note: VACUUM cannot be run inside a transaction block
-- Run these commands separately after migration:
-- VACUUM ANALYZE public.warehouse_stock;
-- VACUUM ANALYZE public.purchase_orders;
-- VACUUM ANALYZE public.delivery_routes;
-- VACUUM ANALYZE public.inventory_transactions;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- To rollback this migration, run:
-- DROP TRIGGER IF EXISTS track_warehouse_stock_trigger ON public.warehouse_stock;
-- DROP FUNCTION IF EXISTS public.track_warehouse_stock_changes();
-- DROP FUNCTION IF EXISTS public.get_warehouse_utilization(UUID);
-- DROP FUNCTION IF EXISTS public.check_reorder_needed(UUID, UUID);
-- DROP FUNCTION IF EXISTS public.get_product_stock_level(UUID, UUID);
-- DROP VIEW IF EXISTS public.delivery_routes_summary;
-- DROP VIEW IF EXISTS public.purchase_orders_summary;
-- DROP VIEW IF EXISTS public.expiring_products;
-- DROP VIEW IF EXISTS public.low_stock_items;
-- ALTER TABLE public.delivery_routes DROP CONSTRAINT IF EXISTS check_delivery_dates_logical;
-- ALTER TABLE public.purchase_orders DROP CONSTRAINT IF EXISTS check_po_total_non_negative;
-- ALTER TABLE public.warehouse_stock DROP CONSTRAINT IF EXISTS check_stock_levels_logical;
-- ALTER TABLE public.suppliers DROP CONSTRAINT IF EXISTS check_supplier_phone_not_empty;
-- ALTER TABLE public.suppliers DROP CONSTRAINT IF EXISTS check_supplier_email_format;
-- DELETE FROM public.schema_migrations WHERE version = '20251208114450';
