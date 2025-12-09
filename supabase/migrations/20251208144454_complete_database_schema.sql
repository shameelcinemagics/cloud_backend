-- ============================================================================
-- COMPLETE DATABASE SCHEMA - VendCloud
-- Generated: 2025-12-08T14:44:54.302Z
-- Description: Complete database schema with all tables, indexes, and policies
-- ============================================================================

-- Migration tracking
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT
);

INSERT INTO public.schema_migrations (version, description)
VALUES ('20251208144454', 'Complete database schema - all tables')
ON CONFLICT (version) DO NOTHING;

-- ============================================================================
-- CORE AUTHENTICATION & AUTHORIZATION TABLES
-- ============================================================================

-- 1. Roles
CREATE TABLE IF NOT EXISTS public.roles (
  id BIGSERIAL PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  label TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_roles_slug ON public.roles(slug);

-- Insert default roles
INSERT INTO public.roles (slug, label) VALUES
  ('admin', 'Admin'),
  ('manager', 'Manager'),
  ('operator', 'Operator')
ON CONFLICT (slug) DO NOTHING;

-- 2. Pages (for permissions)
CREATE TABLE IF NOT EXISTS public.pages (
  id BIGSERIAL PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  label TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pages_slug ON public.pages(slug);

-- Insert default pages
INSERT INTO public.pages (slug, label, description) VALUES
  ('dashboard', 'Dashboard', 'Main dashboard'),
  ('machines', 'Vending Machines', 'Manage vending machines and slots'),
  ('products', 'Products', 'Manage product catalog'),
  ('inventory', 'Inventory', 'Inventory management'),
  ('sales', 'Sales', 'View sales transactions and reports'),
  ('finance', 'Finance', 'Financial reports'),
  ('support', 'Support', 'Customer support'),
  ('media', 'Media', 'Manage marketing content and signage'),
  ('marketing', 'Marketing / Signage', 'Marketing and digital signage management'),
  ('users', 'Users', 'User management'),
  ('settings', 'Settings', 'System settings'),
  ('suppliers', 'Suppliers', 'Manage suppliers and vendors'),
  ('purchase_orders', 'Purchase Orders', 'Create and manage purchase orders'),
  ('warehouse', 'Warehouse', 'Warehouse management and stock control'),
  ('delivery_routes', 'Delivery Routes', 'Route planning and delivery management'),
  ('stock_reports', 'Stock Reports', 'Stock reports and analytics')
ON CONFLICT (slug) DO NOTHING;

-- 3. User Roles (links users to roles)
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id BIGINT NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON public.user_roles(role_id);

-- 4. Role Page Permissions
CREATE TABLE IF NOT EXISTS public.role_page_perms (
  role_id BIGINT REFERENCES public.roles(id) ON DELETE CASCADE,
  page_id BIGINT REFERENCES public.pages(id) ON DELETE CASCADE,
  perms_mask INT NOT NULL CHECK (perms_mask >= 0 AND perms_mask <= 15),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (role_id, page_id)
);

CREATE INDEX IF NOT EXISTS idx_role_page_perms_role_id ON public.role_page_perms(role_id);
CREATE INDEX IF NOT EXISTS idx_role_page_perms_page_id ON public.role_page_perms(page_id);

-- 5. User Page Permissions (overrides)
CREATE TABLE IF NOT EXISTS public.user_page_perms (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  page_id BIGINT REFERENCES public.pages(id) ON DELETE CASCADE,
  perms_mask INT NOT NULL CHECK (perms_mask >= 0 AND perms_mask <= 15),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, page_id)
);

CREATE INDEX IF NOT EXISTS idx_user_page_perms_user_id ON public.user_page_perms(user_id);
CREATE INDEX IF NOT EXISTS idx_user_page_perms_page_id ON public.user_page_perms(page_id);

-- 6. Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- 7. Audit Logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON public.audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- ============================================================================
-- VENDING MACHINE OPERATIONS TABLES
-- ============================================================================

-- 8. Products
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  price NUMERIC NOT NULL CHECK (price >= 0),
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ingredients TEXT,
  health_rating INTEGER CHECK ((health_rating IS NULL) OR (health_rating >= 1 AND health_rating <= 3)),
  calories NUMERIC,
  fat NUMERIC,
  carbs NUMERIC,
  protein NUMERIC,
  sodium NUMERIC,
  category TEXT,
  "partNo" NUMERIC UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_products_name ON public.products(name);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_partNo ON public.products("partNo");

-- 9. Vending Machines
CREATE TABLE IF NOT EXISTS public.vending_machines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id TEXT UNIQUE NOT NULL,
  location TEXT NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance', 'offline')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vending_machines_machine_id ON public.vending_machines(machine_id);
CREATE INDEX IF NOT EXISTS idx_vending_machines_status ON public.vending_machines(status);

-- 10. Slots
CREATE TABLE IF NOT EXISTS public.slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vending_machine_id UUID NOT NULL REFERENCES public.vending_machines(id) ON DELETE CASCADE,
  slot_number INTEGER NOT NULL CHECK (slot_number > 0),
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  quantity INTEGER DEFAULT 0 CHECK (quantity >= 0),
  max_capacity INTEGER DEFAULT 10 CHECK (max_capacity > 0),
  custom_price NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vending_machine_id, slot_number)
);

CREATE INDEX IF NOT EXISTS idx_slots_vending_machine ON public.slots(vending_machine_id);
CREATE INDEX IF NOT EXISTS idx_slots_product ON public.slots(product_id);

-- 11. Sales
CREATE TABLE IF NOT EXISTS public.sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vending_machine_id UUID NOT NULL REFERENCES public.vending_machines(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  slot_number INTEGER NOT NULL,
  quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
  unit_price NUMERIC(10, 3) NOT NULL CHECK (unit_price >= 0),
  sold_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_vending_machine ON public.sales(vending_machine_id);
CREATE INDEX IF NOT EXISTS idx_sales_product ON public.sales(product_id);
CREATE INDEX IF NOT EXISTS idx_sales_sold_at ON public.sales(sold_at DESC);

-- 12. Media
CREATE TABLE IF NOT EXISTS public.media (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT NOT NULL,
  url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_type ON public.media(type);

-- 13. Machine Media
CREATE TABLE IF NOT EXISTS public.machine_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vending_machine_id UUID REFERENCES public.vending_machines(id) ON DELETE CASCADE,
  media_id BIGINT REFERENCES public.media(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_machine_media_vending_machine ON public.machine_media(vending_machine_id);
CREATE INDEX IF NOT EXISTS idx_machine_media_media ON public.machine_media(media_id);

-- 14. Transactions
CREATE TABLE IF NOT EXISTS public.transactions (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  "transationId" TEXT NOT NULL,
  product TEXT NOT NULL,
  status TEXT NOT NULL,
  machine TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_machine ON public.transactions(machine);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);

-- ============================================================================
-- WAREHOUSE & INVENTORY TABLES
-- ============================================================================

-- 15. Suppliers
CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  contact_person TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  country_code TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_company_name ON public.suppliers(company_name);

-- 16. Warehouses
CREATE TABLE IF NOT EXISTS public.warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  warehouse_image_url TEXT,
  location_coordinate TEXT,
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


-- 17. Warehouse Stock
CREATE TABLE IF NOT EXISTS public.warehouse_stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER DEFAULT 0 CHECK (quantity >= 0),
  min_stock_level INTEGER DEFAULT 0,
  max_stock_level INTEGER,
  unit_cost NUMERIC(10,3) DEFAULT 0,
  expiry_date DATE,
  batch_number TEXT,
  last_purchase_date DATE,
  last_purchase_price NUMERIC(10,3),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(warehouse_id, product_id, batch_number)
);

CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse ON public.warehouse_stock(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON public.warehouse_stock(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_expiry ON public.warehouse_stock(expiry_date);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse_product ON public.warehouse_stock(warehouse_id, product_id);

-- 18. Purchase Orders
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
  total_amount NUMERIC(10,3) DEFAULT 0,
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
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status_supplier ON public.purchase_orders(status, supplier_id);

-- 19. Purchase Order Items
CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(10,3) NOT NULL,
  subtotal NUMERIC(10,3) DEFAULT 0,
  received_quantity INTEGER DEFAULT 0 CHECK (received_quantity >= 0),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_po_items_order ON public.purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_po_items_product ON public.purchase_order_items(product_id);

-- 20. Delivery Routes
CREATE TABLE IF NOT EXISTS public.delivery_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  person_in_charge_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  machines UUID[] DEFAULT '{}',
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
CREATE INDEX IF NOT EXISTS idx_delivery_routes_status_date ON public.delivery_routes(delivery_status, route_date);

-- 21. Delivery Route Items
CREATE TABLE IF NOT EXISTS public.delivery_route_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_route_id UUID NOT NULL REFERENCES public.delivery_routes(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  product_vpn TEXT,
  quantity_to_bring INTEGER DEFAULT 0,
  quantity_to_remove INTEGER DEFAULT 0,
  machine_id UUID,
  purchase_order_item_id UUID REFERENCES public.purchase_order_items(id) ON DELETE SET NULL,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  received_quantity INTEGER DEFAULT 0,
  batch_number TEXT,
  expiry_date DATE,
  manufacturing_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_route_items_route ON public.delivery_route_items(delivery_route_id);
CREATE INDEX IF NOT EXISTS idx_dr_items_po_item ON public.delivery_route_items(purchase_order_item_id);
CREATE INDEX IF NOT EXISTS idx_dr_items_warehouse ON public.delivery_route_items(warehouse_id);

-- 22. Stock Adjustments
CREATE TABLE IF NOT EXISTS public.stock_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  adjustment_date DATE DEFAULT CURRENT_DATE,
  adjustment_type TEXT NOT NULL CHECK (adjustment_type IN (
    'purchase', 'damage', 'expired', 'lost', 'extra_bonus',
    'returned_to_supplier', 'claim_to_customer', 'pick_up_to_transit',
    'return_from_transit', 'manual_adjustment'
  )),
  quantity INTEGER NOT NULL,
  previous_quantity INTEGER NOT NULL,
  new_quantity INTEGER NOT NULL,
  unit_price NUMERIC(10,3),
  total_price NUMERIC(10,3),
  remark TEXT,
  source_document TEXT,
  adjusted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments_warehouse ON public.stock_adjustments(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_date ON public.stock_adjustments(adjustment_date);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_type ON public.stock_adjustments(adjustment_type);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_warehouse_date ON public.stock_adjustments(warehouse_id, adjustment_date DESC);

-- 23. Ordering Triggers
CREATE TABLE IF NOT EXISTS public.ordering_triggers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
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

-- 24. Goods Receipt Notes
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

-- 25. Machine Refill Records
CREATE TABLE IF NOT EXISTS public.machine_refill_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_route_id UUID REFERENCES public.delivery_routes(id) ON DELETE CASCADE,
  vending_machine_id UUID REFERENCES public.vending_machines(id) ON DELETE SET NULL,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  slot_id UUID REFERENCES public.slots(id) ON DELETE SET NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
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

-- 26. Inventory Transactions
CREATE TABLE IF NOT EXISTS public.inventory_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN (
    'purchase_receipt', 'machine_refill', 'adjustment', 'expired', 'damaged', 'return'
  )),
  quantity_change INTEGER NOT NULL,
  quantity_before INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  reference_type TEXT,
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
CREATE INDEX IF NOT EXISTS idx_inventory_transactions_warehouse_product ON public.inventory_transactions(warehouse_id, product_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read roles" ON public.roles;
CREATE POLICY "Authenticated users can read roles"
  ON public.roles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access roles" ON public.roles;
CREATE POLICY "Service role full access roles"
  ON public.roles FOR ALL TO service_role USING (true);

ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read pages" ON public.pages;
CREATE POLICY "Authenticated users can read pages"
  ON public.pages FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access pages" ON public.pages;
CREATE POLICY "Service role full access pages"
  ON public.pages FOR ALL TO service_role USING (true);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read user_roles" ON public.user_roles;
CREATE POLICY "Authenticated users can read user_roles"
  ON public.user_roles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access user_roles" ON public.user_roles;
CREATE POLICY "Service role full access user_roles"
  ON public.user_roles FOR ALL TO service_role USING (true);

ALTER TABLE public.role_page_perms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read role_page_perms" ON public.role_page_perms;
CREATE POLICY "Authenticated users can read role_page_perms"
  ON public.role_page_perms FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access role_page_perms" ON public.role_page_perms;
CREATE POLICY "Service role full access role_page_perms"
  ON public.role_page_perms FOR ALL TO service_role USING (true);

ALTER TABLE public.user_page_perms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read user_page_perms" ON public.user_page_perms;
CREATE POLICY "Authenticated users can read user_page_perms"
  ON public.user_page_perms FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access user_page_perms" ON public.user_page_perms;
CREATE POLICY "Service role full access user_page_perms"
  ON public.user_page_perms FOR ALL TO service_role USING (true);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read profiles" ON public.profiles;
CREATE POLICY "Authenticated users can read profiles"
  ON public.profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access profiles" ON public.profiles;
CREATE POLICY "Service role full access profiles"
  ON public.profiles FOR ALL TO service_role USING (true);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read audit_logs" ON public.audit_logs;
CREATE POLICY "Authenticated users can read audit_logs"
  ON public.audit_logs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access audit_logs" ON public.audit_logs;
CREATE POLICY "Service role full access audit_logs"
  ON public.audit_logs FOR ALL TO service_role USING (true);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read products" ON public.products;
CREATE POLICY "Authenticated users can read products"
  ON public.products FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access products" ON public.products;
CREATE POLICY "Service role full access products"
  ON public.products FOR ALL TO service_role USING (true);

ALTER TABLE public.vending_machines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read vending_machines" ON public.vending_machines;
CREATE POLICY "Authenticated users can read vending_machines"
  ON public.vending_machines FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access vending_machines" ON public.vending_machines;
CREATE POLICY "Service role full access vending_machines"
  ON public.vending_machines FOR ALL TO service_role USING (true);

ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read slots" ON public.slots;
CREATE POLICY "Authenticated users can read slots"
  ON public.slots FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access slots" ON public.slots;
CREATE POLICY "Service role full access slots"
  ON public.slots FOR ALL TO service_role USING (true);

ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read sales" ON public.sales;
CREATE POLICY "Authenticated users can read sales"
  ON public.sales FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access sales" ON public.sales;
CREATE POLICY "Service role full access sales"
  ON public.sales FOR ALL TO service_role USING (true);

ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read media" ON public.media;
CREATE POLICY "Authenticated users can read media"
  ON public.media FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access media" ON public.media;
CREATE POLICY "Service role full access media"
  ON public.media FOR ALL TO service_role USING (true);

ALTER TABLE public.machine_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read machine_media" ON public.machine_media;
CREATE POLICY "Authenticated users can read machine_media"
  ON public.machine_media FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access machine_media" ON public.machine_media;
CREATE POLICY "Service role full access machine_media"
  ON public.machine_media FOR ALL TO service_role USING (true);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read transactions" ON public.transactions;
CREATE POLICY "Authenticated users can read transactions"
  ON public.transactions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access transactions" ON public.transactions;
CREATE POLICY "Service role full access transactions"
  ON public.transactions FOR ALL TO service_role USING (true);

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read suppliers" ON public.suppliers;
CREATE POLICY "Authenticated users can read suppliers"
  ON public.suppliers FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access suppliers" ON public.suppliers;
CREATE POLICY "Service role full access suppliers"
  ON public.suppliers FOR ALL TO service_role USING (true);

ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read warehouses" ON public.warehouses;
CREATE POLICY "Authenticated users can read warehouses"
  ON public.warehouses FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access warehouses" ON public.warehouses;
CREATE POLICY "Service role full access warehouses"
  ON public.warehouses FOR ALL TO service_role USING (true);

ALTER TABLE public.warehouse_stock ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read warehouse_stock" ON public.warehouse_stock;
CREATE POLICY "Authenticated users can read warehouse_stock"
  ON public.warehouse_stock FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access warehouse_stock" ON public.warehouse_stock;
CREATE POLICY "Service role full access warehouse_stock"
  ON public.warehouse_stock FOR ALL TO service_role USING (true);

ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read purchase_orders" ON public.purchase_orders;
CREATE POLICY "Authenticated users can read purchase_orders"
  ON public.purchase_orders FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access purchase_orders" ON public.purchase_orders;
CREATE POLICY "Service role full access purchase_orders"
  ON public.purchase_orders FOR ALL TO service_role USING (true);

ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read purchase_order_items" ON public.purchase_order_items;
CREATE POLICY "Authenticated users can read purchase_order_items"
  ON public.purchase_order_items FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access purchase_order_items" ON public.purchase_order_items;
CREATE POLICY "Service role full access purchase_order_items"
  ON public.purchase_order_items FOR ALL TO service_role USING (true);

ALTER TABLE public.delivery_routes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read delivery_routes" ON public.delivery_routes;
CREATE POLICY "Authenticated users can read delivery_routes"
  ON public.delivery_routes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access delivery_routes" ON public.delivery_routes;
CREATE POLICY "Service role full access delivery_routes"
  ON public.delivery_routes FOR ALL TO service_role USING (true);

ALTER TABLE public.delivery_route_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read delivery_route_items" ON public.delivery_route_items;
CREATE POLICY "Authenticated users can read delivery_route_items"
  ON public.delivery_route_items FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access delivery_route_items" ON public.delivery_route_items;
CREATE POLICY "Service role full access delivery_route_items"
  ON public.delivery_route_items FOR ALL TO service_role USING (true);

ALTER TABLE public.stock_adjustments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read stock_adjustments" ON public.stock_adjustments;
CREATE POLICY "Authenticated users can read stock_adjustments"
  ON public.stock_adjustments FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access stock_adjustments" ON public.stock_adjustments;
CREATE POLICY "Service role full access stock_adjustments"
  ON public.stock_adjustments FOR ALL TO service_role USING (true);

ALTER TABLE public.ordering_triggers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read ordering_triggers" ON public.ordering_triggers;
CREATE POLICY "Authenticated users can read ordering_triggers"
  ON public.ordering_triggers FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access ordering_triggers" ON public.ordering_triggers;
CREATE POLICY "Service role full access ordering_triggers"
  ON public.ordering_triggers FOR ALL TO service_role USING (true);

ALTER TABLE public.goods_receipt_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read goods_receipt_notes" ON public.goods_receipt_notes;
CREATE POLICY "Authenticated users can read goods_receipt_notes"
  ON public.goods_receipt_notes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access goods_receipt_notes" ON public.goods_receipt_notes;
CREATE POLICY "Service role full access goods_receipt_notes"
  ON public.goods_receipt_notes FOR ALL TO service_role USING (true);

ALTER TABLE public.machine_refill_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read machine_refill_records" ON public.machine_refill_records;
CREATE POLICY "Authenticated users can read machine_refill_records"
  ON public.machine_refill_records FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access machine_refill_records" ON public.machine_refill_records;
CREATE POLICY "Service role full access machine_refill_records"
  ON public.machine_refill_records FOR ALL TO service_role USING (true);

ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read inventory_transactions" ON public.inventory_transactions;
CREATE POLICY "Authenticated users can read inventory_transactions"
  ON public.inventory_transactions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role full access inventory_transactions" ON public.inventory_transactions;
CREATE POLICY "Service role full access inventory_transactions"
  ON public.inventory_transactions FOR ALL TO service_role USING (true);
