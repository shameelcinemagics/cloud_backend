-- ============================================================================
-- DEPLOYMENT VERIFICATION SCRIPT
-- Run this after deploying to verify everything is working correctly
-- ============================================================================

-- Section 1: Check all tables exist
-- ============================================================================
SELECT 'Checking tables...' AS step;

SELECT
  table_name,
  CASE
    WHEN table_name IN (
      'roles', 'user_roles', 'pages', 'user_page_perms', 'role_page_perms',
      'profiles', 'audit_logs', 'schema_migrations',
      'suppliers', 'warehouses', 'warehouse_stock', 'purchase_orders',
      'purchase_order_items', 'delivery_routes', 'delivery_route_items',
      'stock_adjustments', 'ordering_triggers', 'goods_receipt_notes',
      'machine_refill_records', 'inventory_transactions'
    ) THEN '✅ EXISTS'
    ELSE '❌ UNEXPECTED'
  END AS status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Section 2: Check all views exist
-- ============================================================================
SELECT 'Checking views...' AS step;

SELECT
  table_name AS view_name,
  CASE
    WHEN table_name IN (
      'user_effective_page_perms',
      'low_stock_items',
      'expiring_products',
      'purchase_orders_summary',
      'delivery_routes_summary'
    ) THEN '✅ EXISTS'
    ELSE '❌ UNEXPECTED'
  END AS status
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- Section 3: Check all functions exist
-- ============================================================================
SELECT 'Checking functions...' AS step;

SELECT
  routine_name AS function_name,
  CASE
    WHEN routine_name IN (
      'update_updated_at_column',
      'grant_role_permissions_to_user',
      'generate_po_reference',
      'generate_kitting_code',
      'calculate_po_item_subtotal',
      'update_purchase_order_total',
      'get_product_stock_level',
      'check_reorder_needed',
      'get_warehouse_utilization',
      'track_warehouse_stock_changes'
    ) THEN '✅ EXISTS'
    ELSE '❌ UNEXPECTED'
  END AS status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- Section 4: Check key indexes exist
-- ============================================================================
SELECT 'Checking key indexes...' AS step;

SELECT
  tablename,
  indexname,
  '✅ EXISTS' AS status
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idx_warehouse_stock_warehouse_product',
    'idx_delivery_routes_status_date',
    'idx_purchase_orders_status_supplier',
    'idx_stock_adjustments_warehouse_date',
    'idx_inventory_transactions_warehouse_product'
  )
ORDER BY tablename, indexname;

-- Section 5: Check RLS is enabled
-- ============================================================================
SELECT 'Checking RLS...' AS step;

SELECT
  schemaname,
  tablename,
  CASE
    WHEN rowsecurity THEN '✅ ENABLED'
    ELSE '❌ DISABLED'
  END AS rls_status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Section 6: Test helper functions
-- ============================================================================
SELECT 'Testing helper functions...' AS step;

-- Test get_product_stock_level (should return 0 or number)
SELECT 'Testing get_product_stock_level' AS test;
-- Note: Replace UUIDs with actual values from your database
-- SELECT public.get_product_stock_level(
--   'warehouse-uuid'::uuid,
--   'product-uuid'::uuid
-- ) AS result;

-- Test check_reorder_needed (should return boolean)
SELECT 'Testing check_reorder_needed' AS test;
-- Note: Replace UUIDs with actual values from your database
-- SELECT public.check_reorder_needed(
--   'warehouse-uuid'::uuid,
--   'product-uuid'::uuid
-- ) AS result;

-- Test get_warehouse_utilization (should return percentage)
SELECT 'Testing get_warehouse_utilization' AS test;
-- Note: Replace UUID with actual warehouse ID
-- SELECT public.get_warehouse_utilization(
--   'warehouse-uuid'::uuid
-- ) AS result;

-- Section 7: Test views with sample data
-- ============================================================================
SELECT 'Testing views...' AS step;

-- Test low_stock_items view
SELECT 'Testing low_stock_items view' AS test;
SELECT COUNT(*) AS low_stock_count
FROM public.low_stock_items;

-- Test expiring_products view
SELECT 'Testing expiring_products view' AS test;
SELECT COUNT(*) AS expiring_count
FROM public.expiring_products;

-- Test purchase_orders_summary view
SELECT 'Testing purchase_orders_summary view' AS test;
SELECT COUNT(*) AS po_count
FROM public.purchase_orders_summary;

-- Test delivery_routes_summary view
SELECT 'Testing delivery_routes_summary view' AS test;
SELECT COUNT(*) AS route_count
FROM public.delivery_routes_summary;

-- Section 8: Check constraints
-- ============================================================================
SELECT 'Checking constraints...' AS step;

SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  contype AS constraint_type,
  '✅ EXISTS' AS status
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conname IN (
    'check_supplier_email_format',
    'check_supplier_phone_not_empty',
    'check_stock_levels_logical',
    'check_po_total_non_negative',
    'check_delivery_dates_logical'
  )
ORDER BY conrelid::regclass::text, conname;

-- Section 9: Check migrations applied
-- ============================================================================
SELECT 'Checking migrations...' AS step;

SELECT
  version,
  description,
  applied_at,
  '✅ APPLIED' AS status
FROM public.schema_migrations
ORDER BY version;

-- Section 10: Database statistics
-- ============================================================================
SELECT 'Database statistics...' AS step;

-- Table row counts
SELECT
  schemaname,
  tablename,
  n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;

-- Database size
SELECT
  pg_size_pretty(pg_database_size(current_database())) AS database_size;

-- Top 10 largest tables
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Section 11: Security check
-- ============================================================================
SELECT 'Security check...' AS step;

-- Count policies per table
SELECT
  schemaname,
  tablename,
  COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename
ORDER BY policy_count DESC;

-- Section 12: Performance check
-- ============================================================================
SELECT 'Performance check...' AS step;

-- Index usage statistics (most used indexes)
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan > 0
ORDER BY idx_scan DESC
LIMIT 10;

-- Section 13: Final summary
-- ============================================================================
SELECT '
============================================================================
✅ VERIFICATION COMPLETE
============================================================================

Next steps:
1. Review all sections above for any ❌ marks
2. Test with real UUIDs in Section 6
3. Run VACUUM ANALYZE on key tables:
   - VACUUM ANALYZE public.warehouse_stock;
   - VACUUM ANALYZE public.purchase_orders;
   - VACUUM ANALYZE public.delivery_routes;
   - VACUUM ANALYZE public.inventory_transactions;

4. Set up monitoring for:
   - Low stock alerts (low_stock_items view)
   - Expiring products (expiring_products view)
   - Warehouse capacity (get_warehouse_utilization function)

5. Test the application with the new features!

============================================================================
' AS summary;
