-- Migration: Inventory Integration with Products and Vending Machines
-- Created: 2025-01-19
-- Description: Integrates existing products, slots, vending_machines with warehouse system

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250119000000', 'Inventory Integration - products, vending machines, refill tracking')
ON CONFLICT (version) DO NOTHING;

-- ============================================================================
-- 1. UPDATE PURCHASE ORDER ITEMS TABLE
-- Add received_quantity and notes columns
-- ============================================================================
ALTER TABLE public.purchase_order_items
ADD COLUMN IF NOT EXISTS received_quantity INTEGER DEFAULT 0 CHECK (received_quantity >= 0),
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Drop the old columns if they exist (from previous schema)
ALTER TABLE public.purchase_order_items
DROP COLUMN IF EXISTS description,
DROP COLUMN IF EXISTS packing,
DROP COLUMN IF NOT EXISTS packs,
DROP COLUMN IF EXISTS singles,
DROP COLUMN IF EXISTS packing_price;

-- Update the subtotal to be a regular column instead of GENERATED
ALTER TABLE public.purchase_order_items
DROP COLUMN IF EXISTS subtotal;

ALTER TABLE public.purchase_order_items
ADD COLUMN IF NOT EXISTS subtotal DECIMAL(10,3) DEFAULT 0;

-- Add trigger to auto-calculate subtotal
DROP TRIGGER IF EXISTS calculate_po_item_subtotal_trigger ON public.purchase_order_items;
CREATE TRIGGER calculate_po_item_subtotal_trigger
  BEFORE INSERT OR UPDATE OF quantity, unit_price ON public.purchase_order_items
  FOR EACH ROW
  EXECUTE FUNCTION (
    CREATE OR REPLACE FUNCTION public.calculate_po_item_subtotal()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.subtotal = NEW.quantity * NEW.unit_price;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
  );

-- Update trigger for updated_at
DROP TRIGGER IF EXISTS update_purchase_order_items_updated_at ON public.purchase_order_items;
CREATE TRIGGER update_purchase_order_items_updated_at
  BEFORE UPDATE ON public.purchase_order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 2. UPDATE DELIVERY ROUTE ITEMS TABLE
-- Add columns for warehouse integration
-- ============================================================================
ALTER TABLE public.delivery_route_items
ADD COLUMN IF NOT EXISTS purchase_order_item_id UUID REFERENCES public.purchase_order_items(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS received_quantity INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS batch_number TEXT,
ADD COLUMN IF NOT EXISTS expiry_date DATE,
ADD COLUMN IF NOT EXISTS manufacturing_date DATE;

-- Rename route_id to delivery_route_id for consistency
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name='delivery_route_items' AND column_name='route_id') THEN
    ALTER TABLE public.delivery_route_items RENAME COLUMN route_id TO delivery_route_id;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_dr_items_po_item ON public.delivery_route_items(purchase_order_item_id);
CREATE INDEX IF NOT EXISTS idx_dr_items_warehouse ON public.delivery_route_items(warehouse_id);

-- ============================================================================
-- 3. MACHINE REFILL RECORDS TABLE (NEW)
-- Track all refill operations for vending machines
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.machine_refill_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_route_id UUID REFERENCES public.delivery_routes(id) ON DELETE CASCADE,
  vending_machine_id UUID,  -- References vending_machines table
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  slot_id UUID,  -- References slots table
  product_id UUID,  -- References products table
  quantity_added INTEGER DEFAULT 0,
  quantity_removed INTEGER DEFAULT 0,
  old_quantity INTEGER DEFAULT 0,
  new_quantity INTEGER DEFAULT 0,
  expiry_date DATE,
  batch_number TEXT,
  notes TEXT,
  refilled_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  refilled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refill_route ON public.machine_refill_records(delivery_route_id);
CREATE INDEX IF NOT EXISTS idx_refill_machine ON public.machine_refill_records(vending_machine_id);
CREATE INDEX IF NOT EXISTS idx_refill_warehouse ON public.machine_refill_records(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_refill_product ON public.machine_refill_records(product_id);

-- ============================================================================
-- 4. INVENTORY TRANSACTIONS TABLE (NEW)
-- Complete audit trail of all inventory movements
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.inventory_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id UUID,  -- References products table
  transaction_type TEXT NOT NULL CHECK (transaction_type IN (
    'purchase_receipt', 'machine_refill', 'adjustment', 'expired', 'damaged', 'return'
  )),
  quantity_change INTEGER NOT NULL, -- positive for additions, negative for removals
  quantity_before INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  reference_type TEXT, -- 'purchase_order', 'delivery_route', 'manual'
  reference_id UUID,
  batch_number TEXT,
  expiry_date DATE,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inv_trans_warehouse ON public.inventory_transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inv_trans_product ON public.inventory_transactions(product_id);
CREATE INDEX IF NOT EXISTS idx_inv_trans_type ON public.inventory_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_inv_trans_created ON public.inventory_transactions(created_at);

-- ============================================================================
-- 5. FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update purchase order total when items change
CREATE OR REPLACE FUNCTION public.update_purchase_order_total()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.purchase_orders
  SET total_amount = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM public.purchase_order_items
    WHERE purchase_order_id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id)
  )
  WHERE id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_po_total_on_item_change ON public.purchase_order_items;
CREATE TRIGGER update_po_total_on_item_change
  AFTER INSERT OR UPDATE OR DELETE ON public.purchase_order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.update_purchase_order_total();

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE public.machine_refill_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Authenticated users can read machine_refill_records" ON public.machine_refill_records;
CREATE POLICY "Authenticated users can read machine_refill_records"
  ON public.machine_refill_records FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access machine_refill_records" ON public.machine_refill_records;
CREATE POLICY "Service role full access machine_refill_records"
  ON public.machine_refill_records FOR ALL TO service_role USING (true);

DROP POLICY IF EXISTS "Authenticated users can read inventory_transactions" ON public.inventory_transactions;
CREATE POLICY "Authenticated users can read inventory_transactions"
  ON public.inventory_transactions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access inventory_transactions" ON public.inventory_transactions;
CREATE POLICY "Service role full access inventory_transactions"
  ON public.inventory_transactions FOR ALL TO service_role USING (true);

-- ============================================================================
-- 7. COMMENTS
-- ============================================================================
COMMENT ON TABLE public.machine_refill_records IS 'Historical record of vending machine refills';
COMMENT ON TABLE public.inventory_transactions IS 'Complete audit trail of inventory movements';
COMMENT ON COLUMN public.purchase_order_items.received_quantity IS 'Quantity actually received (may differ from ordered)';
COMMENT ON COLUMN public.delivery_route_items.purchase_order_item_id IS 'Links route items to PO items';

-- ============================================================================
-- 8. ROLLBACK INSTRUCTIONS
-- ============================================================================
-- To rollback this migration, run:
-- DROP TABLE IF EXISTS public.inventory_transactions CASCADE;
-- DROP TABLE IF EXISTS public.machine_refill_records CASCADE;
-- ALTER TABLE public.delivery_route_items DROP COLUMN IF EXISTS purchase_order_item_id;
-- ALTER TABLE public.delivery_route_items DROP COLUMN IF EXISTS warehouse_id;
-- ALTER TABLE public.delivery_route_items DROP COLUMN IF EXISTS received_quantity;
-- ALTER TABLE public.delivery_route_items DROP COLUMN IF EXISTS batch_number;
-- ALTER TABLE public.delivery_route_items DROP COLUMN IF EXISTS expiry_date;
-- ALTER TABLE public.delivery_route_items DROP COLUMN IF EXISTS manufacturing_date;
-- ALTER TABLE public.purchase_order_items DROP COLUMN IF EXISTS received_quantity;
-- ALTER TABLE public.purchase_order_items DROP COLUMN IF EXISTS notes;
-- DROP FUNCTION IF EXISTS public.update_purchase_order_total();
-- DROP FUNCTION IF EXISTS public.calculate_po_item_subtotal();
-- DELETE FROM public.schema_migrations WHERE version = '20250119000000';
