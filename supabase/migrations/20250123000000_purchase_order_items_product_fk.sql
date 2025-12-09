-- Migration: Purchase Order Items Product Foreign Key
-- Created: 2025-01-23
-- Description: Adds foreign key constraint from purchase_order_items.product_id to products.id
-- This enables Supabase/PostgREST to automatically join purchase_order_items with products

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250123000000', 'Purchase order items product foreign key constraint')
ON CONFLICT (version) DO NOTHING;

-- ===== Add Foreign Key Constraint =====
-- Add foreign key from purchase_order_items.product_id to products.id
-- Using ON DELETE RESTRICT to prevent deleting products that are in purchase orders

-- First, make sure the column is NOT NULL (it should be already)
ALTER TABLE public.purchase_order_items
ALTER COLUMN product_id SET NOT NULL;

-- Add the foreign key constraint
ALTER TABLE public.purchase_order_items
DROP CONSTRAINT IF EXISTS fk_purchase_order_items_product;

ALTER TABLE public.purchase_order_items
ADD CONSTRAINT fk_purchase_order_items_product
FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_po_items_product ON public.purchase_order_items(product_id);

-- ===== Also add foreign keys for other tables that reference products =====

-- warehouse_stock.product_id
ALTER TABLE public.warehouse_stock
DROP CONSTRAINT IF EXISTS fk_warehouse_stock_product;

ALTER TABLE public.warehouse_stock
ADD CONSTRAINT fk_warehouse_stock_product
FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- delivery_route_items.product_id
ALTER TABLE public.delivery_route_items
DROP CONSTRAINT IF EXISTS fk_delivery_route_items_product;

ALTER TABLE public.delivery_route_items
ADD CONSTRAINT fk_delivery_route_items_product
FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- stock_adjustments.product_id
ALTER TABLE public.stock_adjustments
DROP CONSTRAINT IF EXISTS fk_stock_adjustments_product;

ALTER TABLE public.stock_adjustments
ADD CONSTRAINT fk_stock_adjustments_product
FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- ordering_triggers.product_id
ALTER TABLE public.ordering_triggers
DROP CONSTRAINT IF EXISTS fk_ordering_triggers_product;

ALTER TABLE public.ordering_triggers
ADD CONSTRAINT fk_ordering_triggers_product
FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

-- Comments
COMMENT ON CONSTRAINT fk_purchase_order_items_product ON public.purchase_order_items IS 'Foreign key linking purchase order items to products';
COMMENT ON CONSTRAINT fk_warehouse_stock_product ON public.warehouse_stock IS 'Foreign key linking warehouse stock to products';
COMMENT ON CONSTRAINT fk_delivery_route_items_product ON public.delivery_route_items IS 'Foreign key linking delivery route items to products';
COMMENT ON CONSTRAINT fk_stock_adjustments_product ON public.stock_adjustments IS 'Foreign key linking stock adjustments to products';
COMMENT ON CONSTRAINT fk_ordering_triggers_product ON public.ordering_triggers IS 'Foreign key linking ordering triggers to products';

-- ===== ROLLBACK INSTRUCTIONS =====
-- To rollback this migration, run:
-- ALTER TABLE public.purchase_order_items DROP CONSTRAINT IF EXISTS fk_purchase_order_items_product;
-- ALTER TABLE public.warehouse_stock DROP CONSTRAINT IF EXISTS fk_warehouse_stock_product;
-- ALTER TABLE public.delivery_route_items DROP CONSTRAINT IF EXISTS fk_delivery_route_items_product;
-- ALTER TABLE public.stock_adjustments DROP CONSTRAINT IF EXISTS fk_stock_adjustments_product;
-- ALTER TABLE public.ordering_triggers DROP CONSTRAINT IF EXISTS fk_ordering_triggers_product;
-- DROP INDEX IF EXISTS idx_po_items_product;
-- DELETE FROM public.schema_migrations WHERE version = '20250123000000';
