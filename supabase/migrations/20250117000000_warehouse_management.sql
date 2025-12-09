-- Migration: Warehouse Management System
-- Created: 2025-01-17
-- Description: Creates tables for suppliers, warehouses, purchase orders, stock management, and delivery routes

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250117000000', 'Warehouse Management System - suppliers, warehouses, purchase orders, routes')
ON CONFLICT (version) DO NOTHING;

-- ===== SUPPLIERS TABLE =====
CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  email TEXT,
  company_registration TEXT,
  phone_number TEXT,
  fax_number TEXT,
  bank_name TEXT,
  bank_account_no TEXT,
  swift_code TEXT,
  company_intro TEXT,
  country TEXT DEFAULT 'Kuwait',
  state_province TEXT,
  address_line1 TEXT,
  address_line2 TEXT,
  address_line3 TEXT,
  postal_zip_code TEXT,
  city TEXT,
  contact_person TEXT,
  website TEXT,
  tax_id TEXT,
  payment_terms TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_company_name ON public.suppliers(company_name);
CREATE INDEX IF NOT EXISTS idx_suppliers_status ON public.suppliers(status);

-- ===== WAREHOUSES TABLE =====
CREATE TABLE IF NOT EXISTS public.warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  warehouse_image_url TEXT,
  location_coordinate TEXT, -- Format: "lat,lng"
  location_name TEXT,
  address TEXT,
  sub_warehouse_of UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  ignore_stock_quantity_during_restock BOOLEAN DEFAULT FALSE,
  is_preferred BOOLEAN DEFAULT FALSE,
  phone TEXT,
  email TEXT,
  warehouse_type TEXT CHECK (warehouse_type IN ('main', 'regional', 'distribution', 'cold_storage', 'other')),
  location_type TEXT CHECK (location_type IN ('cash_room', 'client_location', 'standalone')),
  management_types TEXT[] DEFAULT '{}',
  external_id TEXT,
  description TEXT,
  working_days TEXT[] DEFAULT '{}',
  working_hours_from TIME,
  working_hours_to TIME,
  has_time_interval BOOLEAN DEFAULT FALSE,
  custom_room TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_warehouses_name ON public.warehouses(name);
CREATE INDEX IF NOT EXISTS idx_warehouses_is_preferred ON public.warehouses(is_preferred);

-- ===== WAREHOUSE STOCK TABLE =====
CREATE TABLE IF NOT EXISTS public.warehouse_stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL, -- References your existing products table
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  min_stock_level INTEGER DEFAULT 0,
  max_stock_level INTEGER,
  unit_cost DECIMAL(10,3) DEFAULT 0,
  expiry_date DATE,
  batch_number TEXT,
  last_purchase_date DATE,
  last_purchase_price DECIMAL(10,3),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(warehouse_id, product_id, batch_number)
);

CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse ON public.warehouse_stock(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON public.warehouse_stock(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_expiry ON public.warehouse_stock(expiry_date);

-- ===== PURCHASE ORDERS TABLE =====
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT UNIQUE NOT NULL,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  vendor_reference TEXT,
  buyer_name TEXT,
  delivery_address TEXT,
  currency TEXT DEFAULT 'KWD',
  order_deadline TIMESTAMP WITH TIME ZONE,
  expected_arrival TIMESTAMP WITH TIME ZONE,
  deliver_to_warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  total_amount DECIMAL(10,3) DEFAULT 0,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'locked', 'sent', 'received', 'cancelled')),
  terms_and_conditions TEXT,
  source_document TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  confirmed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  confirmation_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_reference ON public.purchase_orders(reference);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier ON public.purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON public.purchase_orders(status);

-- ===== PURCHASE ORDER ITEMS TABLE =====
CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  description TEXT,
  packing TEXT,
  packs INTEGER DEFAULT 1,
  singles INTEGER DEFAULT 0,
  packing_price DECIMAL(10,3) DEFAULT 0,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,3) NOT NULL,
  subtotal DECIMAL(10,3) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_po_items_order ON public.purchase_order_items(purchase_order_id);

-- ===== DELIVERY ROUTES TABLE =====
CREATE TABLE IF NOT EXISTS public.delivery_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  person_in_charge_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  machine_group TEXT,
  machines UUID[] DEFAULT '{}', -- Array of machine IDs
  delivery_status TEXT DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'in_route', 'completed', 'cancelled')),
  kitting_code TEXT UNIQUE,
  route_date DATE DEFAULT CURRENT_DATE,
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_routes_status ON public.delivery_routes(delivery_status);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_date ON public.delivery_routes(route_date);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_person ON public.delivery_routes(person_in_charge_id);

-- ===== ROUTE ITEMS (Products to Bring/Remove) =====
CREATE TABLE IF NOT EXISTS public.delivery_route_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID NOT NULL REFERENCES public.delivery_routes(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  product_vpn TEXT,
  quantity_to_bring INTEGER DEFAULT 0,
  quantity_to_remove INTEGER DEFAULT 0,
  machine_id UUID, -- Specific machine for this item
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_route_items_route ON public.delivery_route_items(route_id);

-- ===== STOCK ADJUSTMENTS TABLE =====
CREATE TABLE IF NOT EXISTS public.stock_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  adjustment_date DATE DEFAULT CURRENT_DATE,
  adjustment_type TEXT NOT NULL CHECK (adjustment_type IN (
    'purchase', 'damage', 'expired', 'lost', 'extra_bonus',
    'returned_to_supplier', 'claim_to_customer', 'pick_up_to_transit',
    'return_from_transit', 'manual_adjustment'
  )),
  quantity INTEGER NOT NULL, -- Positive for additions, negative for removals
  previous_quantity INTEGER NOT NULL,
  new_quantity INTEGER NOT NULL,
  unit_price DECIMAL(10,3),
  total_price DECIMAL(10,3),
  remark TEXT,
  source_document TEXT, -- PO reference, route reference, etc.
  adjusted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments_warehouse ON public.stock_adjustments(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_date ON public.stock_adjustments(adjustment_date);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_type ON public.stock_adjustments(adjustment_type);

-- ===== ORDERING TRIGGERS (Automatic Reorder) =====
CREATE TABLE IF NOT EXISTS public.ordering_triggers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  product_id UUID NOT NULL,
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  min_quantity INTEGER NOT NULL CHECK (min_quantity >= 0),
  max_quantity INTEGER NOT NULL CHECK (max_quantity >= min_quantity),
  unit_of_measure TEXT DEFAULT 'Units',
  auto_order_enabled BOOLEAN DEFAULT FALSE,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  last_triggered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ordering_triggers_product ON public.ordering_triggers(product_id);
CREATE INDEX IF NOT EXISTS idx_ordering_triggers_warehouse ON public.ordering_triggers(warehouse_id);

-- ===== GOODS RECEIPT NOTE (GRN) =====
CREATE TABLE IF NOT EXISTS public.goods_receipt_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference TEXT UNIQUE NOT NULL,
  purchase_order_id UUID REFERENCES public.purchase_orders(id) ON DELETE SET NULL,
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  received_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  received_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  quality_check_status TEXT DEFAULT 'pending' CHECK (quality_check_status IN ('pending', 'passed', 'failed', 'partial')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_grn_po ON public.goods_receipt_notes(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_warehouse ON public.goods_receipt_notes(warehouse_id);

-- ===== UPDATE TRIGGERS =====
DROP TRIGGER IF EXISTS update_suppliers_updated_at ON public.suppliers;
CREATE TRIGGER update_suppliers_updated_at
  BEFORE UPDATE ON public.suppliers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_warehouses_updated_at ON public.warehouses;
CREATE TRIGGER update_warehouses_updated_at
  BEFORE UPDATE ON public.warehouses
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_warehouse_stock_updated_at ON public.warehouse_stock;
CREATE TRIGGER update_warehouse_stock_updated_at
  BEFORE UPDATE ON public.warehouse_stock
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_purchase_orders_updated_at ON public.purchase_orders;
CREATE TRIGGER update_purchase_orders_updated_at
  BEFORE UPDATE ON public.purchase_orders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_delivery_routes_updated_at ON public.delivery_routes;
CREATE TRIGGER update_delivery_routes_updated_at
  BEFORE UPDATE ON public.delivery_routes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_ordering_triggers_updated_at ON public.ordering_triggers;
CREATE TRIGGER update_ordering_triggers_updated_at
  BEFORE UPDATE ON public.ordering_triggers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ===== ROW LEVEL SECURITY =====
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_route_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ordering_triggers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goods_receipt_notes ENABLE ROW LEVEL SECURITY;

-- RLS Policies - Authenticated users can read all warehouse data
CREATE POLICY "Authenticated users can read suppliers" ON public.suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read warehouses" ON public.warehouses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read warehouse_stock" ON public.warehouse_stock FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read purchase_orders" ON public.purchase_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read purchase_order_items" ON public.purchase_order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read delivery_routes" ON public.delivery_routes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read delivery_route_items" ON public.delivery_route_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read stock_adjustments" ON public.stock_adjustments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read ordering_triggers" ON public.ordering_triggers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can read goods_receipt_notes" ON public.goods_receipt_notes FOR SELECT TO authenticated USING (true);

-- Service role can do everything
CREATE POLICY "Service role full access suppliers" ON public.suppliers FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access warehouses" ON public.warehouses FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access warehouse_stock" ON public.warehouse_stock FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access purchase_orders" ON public.purchase_orders FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access purchase_order_items" ON public.purchase_order_items FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access delivery_routes" ON public.delivery_routes FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access delivery_route_items" ON public.delivery_route_items FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access stock_adjustments" ON public.stock_adjustments FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access ordering_triggers" ON public.ordering_triggers FOR ALL TO service_role USING (true);
CREATE POLICY "Service role full access goods_receipt_notes" ON public.goods_receipt_notes FOR ALL TO service_role USING (true);

-- ===== ADD NEW PAGES FOR PERMISSIONS =====
INSERT INTO public.pages (slug, label, description) VALUES
  ('suppliers', 'Suppliers', 'Manage suppliers and vendors'),
  ('purchase_orders', 'Purchase Orders', 'Create and manage purchase orders'),
  ('warehouse', 'Warehouse', 'Warehouse management and stock control'),
  ('delivery_routes', 'Delivery Routes', 'Route planning and delivery management'),
  ('stock_reports', 'Stock Reports', 'Stock reports and analytics')
ON CONFLICT (slug) DO NOTHING;

-- Give admin role full CRUD on new pages
INSERT INTO public.role_page_perms (role_id, page_id, perms_mask)
SELECT
  r.id AS role_id,
  p.id AS page_id,
  15 AS perms_mask
FROM public.roles r
CROSS JOIN public.pages p
WHERE r.slug = 'admin' AND p.slug IN ('suppliers', 'purchase_orders', 'warehouse', 'delivery_routes', 'stock_reports')
ON CONFLICT (role_id, page_id) DO NOTHING;

-- ===== HELPER FUNCTION: Generate PO Reference =====
CREATE OR REPLACE FUNCTION public.generate_po_reference()
RETURNS TEXT AS $$
DECLARE
  year_part TEXT;
  seq_num INTEGER;
  new_ref TEXT;
BEGIN
  year_part := TO_CHAR(CURRENT_DATE, 'YYYY');

  SELECT COALESCE(MAX(
    CAST(SUBSTRING(reference FROM 'PO/' || year_part || '/(\d+)$') AS INTEGER)
  ), 0) + 1
  INTO seq_num
  FROM public.purchase_orders
  WHERE reference LIKE 'PO/' || year_part || '/%';

  new_ref := 'PO/' || year_part || '/' || LPAD(seq_num::TEXT, 6, '0');
  RETURN new_ref;
END;
$$ LANGUAGE plpgsql;

-- ===== HELPER FUNCTION: Generate Kitting Code =====
CREATE OR REPLACE FUNCTION public.generate_kitting_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := 'RAP';
  i INTEGER;
BEGIN
  FOR i IN 1..4 LOOP
    result := result || SUBSTR(chars, FLOOR(RANDOM() * LENGTH(chars) + 1)::INTEGER, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.generate_po_reference() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_kitting_code() TO authenticated;

-- Comments
COMMENT ON TABLE public.suppliers IS 'Vendor/Supplier information';
COMMENT ON TABLE public.warehouses IS 'Warehouse locations and configuration';
COMMENT ON TABLE public.warehouse_stock IS 'Current stock levels per warehouse';
COMMENT ON TABLE public.purchase_orders IS 'Purchase orders to suppliers';
COMMENT ON TABLE public.delivery_routes IS 'Delivery routes for vending machine refilling';
COMMENT ON TABLE public.stock_adjustments IS 'Stock movement audit trail';
COMMENT ON TABLE public.ordering_triggers IS 'Automatic reorder rules';

-- ===== ROLLBACK INSTRUCTIONS =====
-- To rollback this migration, run:
-- DROP TABLE IF EXISTS public.goods_receipt_notes CASCADE;
-- DROP TABLE IF EXISTS public.ordering_triggers CASCADE;
-- DROP TABLE IF EXISTS public.stock_adjustments CASCADE;
-- DROP TABLE IF EXISTS public.delivery_route_items CASCADE;
-- DROP TABLE IF EXISTS public.delivery_routes CASCADE;
-- DROP TABLE IF EXISTS public.purchase_order_items CASCADE;
-- DROP TABLE IF EXISTS public.purchase_orders CASCADE;
-- DROP TABLE IF EXISTS public.warehouse_stock CASCADE;
-- DROP TABLE IF EXISTS public.warehouses CASCADE;
-- DROP TABLE IF EXISTS public.suppliers CASCADE;
-- DROP FUNCTION IF EXISTS public.generate_po_reference();
-- DROP FUNCTION IF EXISTS public.generate_kitting_code();
-- DELETE FROM public.pages WHERE slug IN ('suppliers', 'purchase_orders', 'warehouse', 'delivery_routes', 'stock_reports');
-- DELETE FROM public.schema_migrations WHERE version = '20250117000000';
