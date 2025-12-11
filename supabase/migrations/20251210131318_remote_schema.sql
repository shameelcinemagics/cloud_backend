drop extension if exists "pg_net";

drop trigger if exists "update_delivery_routes_updated_at" on "public"."delivery_routes";

drop trigger if exists "update_ordering_triggers_updated_at" on "public"."ordering_triggers";

drop trigger if exists "update_pages_updated_at" on "public"."pages";

drop trigger if exists "update_profiles_updated_at" on "public"."profiles";

drop trigger if exists "calculate_po_item_subtotal_trigger" on "public"."purchase_order_items";

drop trigger if exists "update_po_total_on_item_change" on "public"."purchase_order_items";

drop trigger if exists "update_purchase_order_items_updated_at" on "public"."purchase_order_items";

drop trigger if exists "update_purchase_orders_updated_at" on "public"."purchase_orders";

drop trigger if exists "update_role_page_perms_updated_at" on "public"."role_page_perms";

drop trigger if exists "update_roles_updated_at" on "public"."roles";

drop trigger if exists "update_suppliers_updated_at" on "public"."suppliers";

drop trigger if exists "update_user_page_perms_updated_at" on "public"."user_page_perms";

drop trigger if exists "trigger_grant_role_permissions" on "public"."user_roles";

drop trigger if exists "update_warehouse_stock_updated_at" on "public"."warehouse_stock";

drop trigger if exists "update_warehouses_updated_at" on "public"."warehouses";

revoke delete on table "public"."audit_logs" from "anon";

revoke insert on table "public"."audit_logs" from "anon";

revoke references on table "public"."audit_logs" from "anon";

revoke select on table "public"."audit_logs" from "anon";

revoke trigger on table "public"."audit_logs" from "anon";

revoke truncate on table "public"."audit_logs" from "anon";

revoke update on table "public"."audit_logs" from "anon";

revoke delete on table "public"."audit_logs" from "authenticated";

revoke insert on table "public"."audit_logs" from "authenticated";

revoke references on table "public"."audit_logs" from "authenticated";

revoke select on table "public"."audit_logs" from "authenticated";

revoke trigger on table "public"."audit_logs" from "authenticated";

revoke truncate on table "public"."audit_logs" from "authenticated";

revoke update on table "public"."audit_logs" from "authenticated";

revoke delete on table "public"."audit_logs" from "service_role";

revoke insert on table "public"."audit_logs" from "service_role";

revoke references on table "public"."audit_logs" from "service_role";

revoke select on table "public"."audit_logs" from "service_role";

revoke trigger on table "public"."audit_logs" from "service_role";

revoke truncate on table "public"."audit_logs" from "service_role";

revoke update on table "public"."audit_logs" from "service_role";

revoke delete on table "public"."delivery_route_items" from "anon";

revoke insert on table "public"."delivery_route_items" from "anon";

revoke references on table "public"."delivery_route_items" from "anon";

revoke select on table "public"."delivery_route_items" from "anon";

revoke trigger on table "public"."delivery_route_items" from "anon";

revoke truncate on table "public"."delivery_route_items" from "anon";

revoke update on table "public"."delivery_route_items" from "anon";

revoke delete on table "public"."delivery_route_items" from "authenticated";

revoke insert on table "public"."delivery_route_items" from "authenticated";

revoke references on table "public"."delivery_route_items" from "authenticated";

revoke select on table "public"."delivery_route_items" from "authenticated";

revoke trigger on table "public"."delivery_route_items" from "authenticated";

revoke truncate on table "public"."delivery_route_items" from "authenticated";

revoke update on table "public"."delivery_route_items" from "authenticated";

revoke delete on table "public"."delivery_route_items" from "service_role";

revoke insert on table "public"."delivery_route_items" from "service_role";

revoke references on table "public"."delivery_route_items" from "service_role";

revoke select on table "public"."delivery_route_items" from "service_role";

revoke trigger on table "public"."delivery_route_items" from "service_role";

revoke truncate on table "public"."delivery_route_items" from "service_role";

revoke update on table "public"."delivery_route_items" from "service_role";

revoke delete on table "public"."delivery_routes" from "anon";

revoke insert on table "public"."delivery_routes" from "anon";

revoke references on table "public"."delivery_routes" from "anon";

revoke select on table "public"."delivery_routes" from "anon";

revoke trigger on table "public"."delivery_routes" from "anon";

revoke truncate on table "public"."delivery_routes" from "anon";

revoke update on table "public"."delivery_routes" from "anon";

revoke delete on table "public"."delivery_routes" from "authenticated";

revoke insert on table "public"."delivery_routes" from "authenticated";

revoke references on table "public"."delivery_routes" from "authenticated";

revoke select on table "public"."delivery_routes" from "authenticated";

revoke trigger on table "public"."delivery_routes" from "authenticated";

revoke truncate on table "public"."delivery_routes" from "authenticated";

revoke update on table "public"."delivery_routes" from "authenticated";

revoke delete on table "public"."delivery_routes" from "service_role";

revoke insert on table "public"."delivery_routes" from "service_role";

revoke references on table "public"."delivery_routes" from "service_role";

revoke select on table "public"."delivery_routes" from "service_role";

revoke trigger on table "public"."delivery_routes" from "service_role";

revoke truncate on table "public"."delivery_routes" from "service_role";

revoke update on table "public"."delivery_routes" from "service_role";

revoke delete on table "public"."goods_receipt_notes" from "anon";

revoke insert on table "public"."goods_receipt_notes" from "anon";

revoke references on table "public"."goods_receipt_notes" from "anon";

revoke select on table "public"."goods_receipt_notes" from "anon";

revoke trigger on table "public"."goods_receipt_notes" from "anon";

revoke truncate on table "public"."goods_receipt_notes" from "anon";

revoke update on table "public"."goods_receipt_notes" from "anon";

revoke delete on table "public"."goods_receipt_notes" from "authenticated";

revoke insert on table "public"."goods_receipt_notes" from "authenticated";

revoke references on table "public"."goods_receipt_notes" from "authenticated";

revoke select on table "public"."goods_receipt_notes" from "authenticated";

revoke trigger on table "public"."goods_receipt_notes" from "authenticated";

revoke truncate on table "public"."goods_receipt_notes" from "authenticated";

revoke update on table "public"."goods_receipt_notes" from "authenticated";

revoke delete on table "public"."goods_receipt_notes" from "service_role";

revoke insert on table "public"."goods_receipt_notes" from "service_role";

revoke references on table "public"."goods_receipt_notes" from "service_role";

revoke select on table "public"."goods_receipt_notes" from "service_role";

revoke trigger on table "public"."goods_receipt_notes" from "service_role";

revoke truncate on table "public"."goods_receipt_notes" from "service_role";

revoke update on table "public"."goods_receipt_notes" from "service_role";

revoke delete on table "public"."inventory_transactions" from "anon";

revoke insert on table "public"."inventory_transactions" from "anon";

revoke references on table "public"."inventory_transactions" from "anon";

revoke select on table "public"."inventory_transactions" from "anon";

revoke trigger on table "public"."inventory_transactions" from "anon";

revoke truncate on table "public"."inventory_transactions" from "anon";

revoke update on table "public"."inventory_transactions" from "anon";

revoke delete on table "public"."inventory_transactions" from "authenticated";

revoke insert on table "public"."inventory_transactions" from "authenticated";

revoke references on table "public"."inventory_transactions" from "authenticated";

revoke select on table "public"."inventory_transactions" from "authenticated";

revoke trigger on table "public"."inventory_transactions" from "authenticated";

revoke truncate on table "public"."inventory_transactions" from "authenticated";

revoke update on table "public"."inventory_transactions" from "authenticated";

revoke delete on table "public"."inventory_transactions" from "service_role";

revoke insert on table "public"."inventory_transactions" from "service_role";

revoke references on table "public"."inventory_transactions" from "service_role";

revoke select on table "public"."inventory_transactions" from "service_role";

revoke trigger on table "public"."inventory_transactions" from "service_role";

revoke truncate on table "public"."inventory_transactions" from "service_role";

revoke update on table "public"."inventory_transactions" from "service_role";

revoke delete on table "public"."machine_refill_records" from "anon";

revoke insert on table "public"."machine_refill_records" from "anon";

revoke references on table "public"."machine_refill_records" from "anon";

revoke select on table "public"."machine_refill_records" from "anon";

revoke trigger on table "public"."machine_refill_records" from "anon";

revoke truncate on table "public"."machine_refill_records" from "anon";

revoke update on table "public"."machine_refill_records" from "anon";

revoke delete on table "public"."machine_refill_records" from "authenticated";

revoke insert on table "public"."machine_refill_records" from "authenticated";

revoke references on table "public"."machine_refill_records" from "authenticated";

revoke select on table "public"."machine_refill_records" from "authenticated";

revoke trigger on table "public"."machine_refill_records" from "authenticated";

revoke truncate on table "public"."machine_refill_records" from "authenticated";

revoke update on table "public"."machine_refill_records" from "authenticated";

revoke delete on table "public"."machine_refill_records" from "service_role";

revoke insert on table "public"."machine_refill_records" from "service_role";

revoke references on table "public"."machine_refill_records" from "service_role";

revoke select on table "public"."machine_refill_records" from "service_role";

revoke trigger on table "public"."machine_refill_records" from "service_role";

revoke truncate on table "public"."machine_refill_records" from "service_role";

revoke update on table "public"."machine_refill_records" from "service_role";

revoke delete on table "public"."ordering_triggers" from "anon";

revoke insert on table "public"."ordering_triggers" from "anon";

revoke references on table "public"."ordering_triggers" from "anon";

revoke select on table "public"."ordering_triggers" from "anon";

revoke trigger on table "public"."ordering_triggers" from "anon";

revoke truncate on table "public"."ordering_triggers" from "anon";

revoke update on table "public"."ordering_triggers" from "anon";

revoke delete on table "public"."ordering_triggers" from "authenticated";

revoke insert on table "public"."ordering_triggers" from "authenticated";

revoke references on table "public"."ordering_triggers" from "authenticated";

revoke select on table "public"."ordering_triggers" from "authenticated";

revoke trigger on table "public"."ordering_triggers" from "authenticated";

revoke truncate on table "public"."ordering_triggers" from "authenticated";

revoke update on table "public"."ordering_triggers" from "authenticated";

revoke delete on table "public"."ordering_triggers" from "service_role";

revoke insert on table "public"."ordering_triggers" from "service_role";

revoke references on table "public"."ordering_triggers" from "service_role";

revoke select on table "public"."ordering_triggers" from "service_role";

revoke trigger on table "public"."ordering_triggers" from "service_role";

revoke truncate on table "public"."ordering_triggers" from "service_role";

revoke update on table "public"."ordering_triggers" from "service_role";

revoke delete on table "public"."pages" from "anon";

revoke insert on table "public"."pages" from "anon";

revoke references on table "public"."pages" from "anon";

revoke select on table "public"."pages" from "anon";

revoke trigger on table "public"."pages" from "anon";

revoke truncate on table "public"."pages" from "anon";

revoke update on table "public"."pages" from "anon";

revoke delete on table "public"."pages" from "authenticated";

revoke insert on table "public"."pages" from "authenticated";

revoke references on table "public"."pages" from "authenticated";

revoke select on table "public"."pages" from "authenticated";

revoke trigger on table "public"."pages" from "authenticated";

revoke truncate on table "public"."pages" from "authenticated";

revoke update on table "public"."pages" from "authenticated";

revoke delete on table "public"."pages" from "service_role";

revoke insert on table "public"."pages" from "service_role";

revoke references on table "public"."pages" from "service_role";

revoke select on table "public"."pages" from "service_role";

revoke trigger on table "public"."pages" from "service_role";

revoke truncate on table "public"."pages" from "service_role";

revoke update on table "public"."pages" from "service_role";

revoke delete on table "public"."purchase_order_items" from "anon";

revoke insert on table "public"."purchase_order_items" from "anon";

revoke references on table "public"."purchase_order_items" from "anon";

revoke select on table "public"."purchase_order_items" from "anon";

revoke trigger on table "public"."purchase_order_items" from "anon";

revoke truncate on table "public"."purchase_order_items" from "anon";

revoke update on table "public"."purchase_order_items" from "anon";

revoke delete on table "public"."purchase_order_items" from "authenticated";

revoke insert on table "public"."purchase_order_items" from "authenticated";

revoke references on table "public"."purchase_order_items" from "authenticated";

revoke select on table "public"."purchase_order_items" from "authenticated";

revoke trigger on table "public"."purchase_order_items" from "authenticated";

revoke truncate on table "public"."purchase_order_items" from "authenticated";

revoke update on table "public"."purchase_order_items" from "authenticated";

revoke delete on table "public"."purchase_order_items" from "service_role";

revoke insert on table "public"."purchase_order_items" from "service_role";

revoke references on table "public"."purchase_order_items" from "service_role";

revoke select on table "public"."purchase_order_items" from "service_role";

revoke trigger on table "public"."purchase_order_items" from "service_role";

revoke truncate on table "public"."purchase_order_items" from "service_role";

revoke update on table "public"."purchase_order_items" from "service_role";

revoke delete on table "public"."purchase_orders" from "anon";

revoke insert on table "public"."purchase_orders" from "anon";

revoke references on table "public"."purchase_orders" from "anon";

revoke select on table "public"."purchase_orders" from "anon";

revoke trigger on table "public"."purchase_orders" from "anon";

revoke truncate on table "public"."purchase_orders" from "anon";

revoke update on table "public"."purchase_orders" from "anon";

revoke delete on table "public"."purchase_orders" from "authenticated";

revoke insert on table "public"."purchase_orders" from "authenticated";

revoke references on table "public"."purchase_orders" from "authenticated";

revoke select on table "public"."purchase_orders" from "authenticated";

revoke trigger on table "public"."purchase_orders" from "authenticated";

revoke truncate on table "public"."purchase_orders" from "authenticated";

revoke update on table "public"."purchase_orders" from "authenticated";

revoke delete on table "public"."purchase_orders" from "service_role";

revoke insert on table "public"."purchase_orders" from "service_role";

revoke references on table "public"."purchase_orders" from "service_role";

revoke select on table "public"."purchase_orders" from "service_role";

revoke trigger on table "public"."purchase_orders" from "service_role";

revoke truncate on table "public"."purchase_orders" from "service_role";

revoke update on table "public"."purchase_orders" from "service_role";

revoke delete on table "public"."role_page_perms" from "anon";

revoke insert on table "public"."role_page_perms" from "anon";

revoke references on table "public"."role_page_perms" from "anon";

revoke select on table "public"."role_page_perms" from "anon";

revoke trigger on table "public"."role_page_perms" from "anon";

revoke truncate on table "public"."role_page_perms" from "anon";

revoke update on table "public"."role_page_perms" from "anon";

revoke delete on table "public"."role_page_perms" from "authenticated";

revoke insert on table "public"."role_page_perms" from "authenticated";

revoke references on table "public"."role_page_perms" from "authenticated";

revoke select on table "public"."role_page_perms" from "authenticated";

revoke trigger on table "public"."role_page_perms" from "authenticated";

revoke truncate on table "public"."role_page_perms" from "authenticated";

revoke update on table "public"."role_page_perms" from "authenticated";

revoke delete on table "public"."role_page_perms" from "service_role";

revoke insert on table "public"."role_page_perms" from "service_role";

revoke references on table "public"."role_page_perms" from "service_role";

revoke select on table "public"."role_page_perms" from "service_role";

revoke trigger on table "public"."role_page_perms" from "service_role";

revoke truncate on table "public"."role_page_perms" from "service_role";

revoke update on table "public"."role_page_perms" from "service_role";

revoke delete on table "public"."roles" from "anon";

revoke insert on table "public"."roles" from "anon";

revoke references on table "public"."roles" from "anon";

revoke select on table "public"."roles" from "anon";

revoke trigger on table "public"."roles" from "anon";

revoke truncate on table "public"."roles" from "anon";

revoke update on table "public"."roles" from "anon";

revoke delete on table "public"."roles" from "authenticated";

revoke insert on table "public"."roles" from "authenticated";

revoke references on table "public"."roles" from "authenticated";

revoke select on table "public"."roles" from "authenticated";

revoke trigger on table "public"."roles" from "authenticated";

revoke truncate on table "public"."roles" from "authenticated";

revoke update on table "public"."roles" from "authenticated";

revoke delete on table "public"."roles" from "service_role";

revoke insert on table "public"."roles" from "service_role";

revoke references on table "public"."roles" from "service_role";

revoke select on table "public"."roles" from "service_role";

revoke trigger on table "public"."roles" from "service_role";

revoke truncate on table "public"."roles" from "service_role";

revoke update on table "public"."roles" from "service_role";

revoke delete on table "public"."schema_migrations" from "anon";

revoke insert on table "public"."schema_migrations" from "anon";

revoke references on table "public"."schema_migrations" from "anon";

revoke select on table "public"."schema_migrations" from "anon";

revoke trigger on table "public"."schema_migrations" from "anon";

revoke truncate on table "public"."schema_migrations" from "anon";

revoke update on table "public"."schema_migrations" from "anon";

revoke delete on table "public"."schema_migrations" from "authenticated";

revoke insert on table "public"."schema_migrations" from "authenticated";

revoke references on table "public"."schema_migrations" from "authenticated";

revoke select on table "public"."schema_migrations" from "authenticated";

revoke trigger on table "public"."schema_migrations" from "authenticated";

revoke truncate on table "public"."schema_migrations" from "authenticated";

revoke update on table "public"."schema_migrations" from "authenticated";

revoke delete on table "public"."schema_migrations" from "service_role";

revoke insert on table "public"."schema_migrations" from "service_role";

revoke references on table "public"."schema_migrations" from "service_role";

revoke select on table "public"."schema_migrations" from "service_role";

revoke trigger on table "public"."schema_migrations" from "service_role";

revoke truncate on table "public"."schema_migrations" from "service_role";

revoke update on table "public"."schema_migrations" from "service_role";

revoke delete on table "public"."stock_adjustments" from "anon";

revoke insert on table "public"."stock_adjustments" from "anon";

revoke references on table "public"."stock_adjustments" from "anon";

revoke select on table "public"."stock_adjustments" from "anon";

revoke trigger on table "public"."stock_adjustments" from "anon";

revoke truncate on table "public"."stock_adjustments" from "anon";

revoke update on table "public"."stock_adjustments" from "anon";

revoke delete on table "public"."stock_adjustments" from "authenticated";

revoke insert on table "public"."stock_adjustments" from "authenticated";

revoke references on table "public"."stock_adjustments" from "authenticated";

revoke select on table "public"."stock_adjustments" from "authenticated";

revoke trigger on table "public"."stock_adjustments" from "authenticated";

revoke truncate on table "public"."stock_adjustments" from "authenticated";

revoke update on table "public"."stock_adjustments" from "authenticated";

revoke delete on table "public"."stock_adjustments" from "service_role";

revoke insert on table "public"."stock_adjustments" from "service_role";

revoke references on table "public"."stock_adjustments" from "service_role";

revoke select on table "public"."stock_adjustments" from "service_role";

revoke trigger on table "public"."stock_adjustments" from "service_role";

revoke truncate on table "public"."stock_adjustments" from "service_role";

revoke update on table "public"."stock_adjustments" from "service_role";

revoke delete on table "public"."suppliers" from "anon";

revoke insert on table "public"."suppliers" from "anon";

revoke references on table "public"."suppliers" from "anon";

revoke select on table "public"."suppliers" from "anon";

revoke trigger on table "public"."suppliers" from "anon";

revoke truncate on table "public"."suppliers" from "anon";

revoke update on table "public"."suppliers" from "anon";

revoke delete on table "public"."suppliers" from "authenticated";

revoke insert on table "public"."suppliers" from "authenticated";

revoke references on table "public"."suppliers" from "authenticated";

revoke select on table "public"."suppliers" from "authenticated";

revoke trigger on table "public"."suppliers" from "authenticated";

revoke truncate on table "public"."suppliers" from "authenticated";

revoke update on table "public"."suppliers" from "authenticated";

revoke delete on table "public"."suppliers" from "service_role";

revoke insert on table "public"."suppliers" from "service_role";

revoke references on table "public"."suppliers" from "service_role";

revoke select on table "public"."suppliers" from "service_role";

revoke trigger on table "public"."suppliers" from "service_role";

revoke truncate on table "public"."suppliers" from "service_role";

revoke update on table "public"."suppliers" from "service_role";

revoke delete on table "public"."user_page_perms" from "anon";

revoke insert on table "public"."user_page_perms" from "anon";

revoke references on table "public"."user_page_perms" from "anon";

revoke select on table "public"."user_page_perms" from "anon";

revoke trigger on table "public"."user_page_perms" from "anon";

revoke truncate on table "public"."user_page_perms" from "anon";

revoke update on table "public"."user_page_perms" from "anon";

revoke delete on table "public"."user_page_perms" from "authenticated";

revoke insert on table "public"."user_page_perms" from "authenticated";

revoke references on table "public"."user_page_perms" from "authenticated";

revoke select on table "public"."user_page_perms" from "authenticated";

revoke trigger on table "public"."user_page_perms" from "authenticated";

revoke truncate on table "public"."user_page_perms" from "authenticated";

revoke update on table "public"."user_page_perms" from "authenticated";

revoke delete on table "public"."user_page_perms" from "service_role";

revoke insert on table "public"."user_page_perms" from "service_role";

revoke references on table "public"."user_page_perms" from "service_role";

revoke select on table "public"."user_page_perms" from "service_role";

revoke trigger on table "public"."user_page_perms" from "service_role";

revoke truncate on table "public"."user_page_perms" from "service_role";

revoke update on table "public"."user_page_perms" from "service_role";

revoke delete on table "public"."user_roles" from "anon";

revoke insert on table "public"."user_roles" from "anon";

revoke references on table "public"."user_roles" from "anon";

revoke select on table "public"."user_roles" from "anon";

revoke trigger on table "public"."user_roles" from "anon";

revoke truncate on table "public"."user_roles" from "anon";

revoke update on table "public"."user_roles" from "anon";

revoke delete on table "public"."user_roles" from "authenticated";

revoke insert on table "public"."user_roles" from "authenticated";

revoke references on table "public"."user_roles" from "authenticated";

revoke select on table "public"."user_roles" from "authenticated";

revoke trigger on table "public"."user_roles" from "authenticated";

revoke truncate on table "public"."user_roles" from "authenticated";

revoke update on table "public"."user_roles" from "authenticated";

revoke delete on table "public"."user_roles" from "service_role";

revoke insert on table "public"."user_roles" from "service_role";

revoke references on table "public"."user_roles" from "service_role";

revoke select on table "public"."user_roles" from "service_role";

revoke trigger on table "public"."user_roles" from "service_role";

revoke truncate on table "public"."user_roles" from "service_role";

revoke update on table "public"."user_roles" from "service_role";

revoke delete on table "public"."warehouse_stock" from "anon";

revoke insert on table "public"."warehouse_stock" from "anon";

revoke references on table "public"."warehouse_stock" from "anon";

revoke select on table "public"."warehouse_stock" from "anon";

revoke trigger on table "public"."warehouse_stock" from "anon";

revoke truncate on table "public"."warehouse_stock" from "anon";

revoke update on table "public"."warehouse_stock" from "anon";

revoke delete on table "public"."warehouse_stock" from "authenticated";

revoke insert on table "public"."warehouse_stock" from "authenticated";

revoke references on table "public"."warehouse_stock" from "authenticated";

revoke select on table "public"."warehouse_stock" from "authenticated";

revoke trigger on table "public"."warehouse_stock" from "authenticated";

revoke truncate on table "public"."warehouse_stock" from "authenticated";

revoke update on table "public"."warehouse_stock" from "authenticated";

revoke delete on table "public"."warehouse_stock" from "service_role";

revoke insert on table "public"."warehouse_stock" from "service_role";

revoke references on table "public"."warehouse_stock" from "service_role";

revoke select on table "public"."warehouse_stock" from "service_role";

revoke trigger on table "public"."warehouse_stock" from "service_role";

revoke truncate on table "public"."warehouse_stock" from "service_role";

revoke update on table "public"."warehouse_stock" from "service_role";

revoke delete on table "public"."warehouses" from "anon";

revoke insert on table "public"."warehouses" from "anon";

revoke references on table "public"."warehouses" from "anon";

revoke select on table "public"."warehouses" from "anon";

revoke trigger on table "public"."warehouses" from "anon";

revoke truncate on table "public"."warehouses" from "anon";

revoke update on table "public"."warehouses" from "anon";

revoke delete on table "public"."warehouses" from "authenticated";

revoke insert on table "public"."warehouses" from "authenticated";

revoke references on table "public"."warehouses" from "authenticated";

revoke select on table "public"."warehouses" from "authenticated";

revoke trigger on table "public"."warehouses" from "authenticated";

revoke truncate on table "public"."warehouses" from "authenticated";

revoke update on table "public"."warehouses" from "authenticated";

revoke delete on table "public"."warehouses" from "service_role";

revoke insert on table "public"."warehouses" from "service_role";

revoke references on table "public"."warehouses" from "service_role";

revoke select on table "public"."warehouses" from "service_role";

revoke trigger on table "public"."warehouses" from "service_role";

revoke truncate on table "public"."warehouses" from "service_role";

revoke update on table "public"."warehouses" from "service_role";

alter table "public"."audit_logs" drop constraint "audit_logs_user_id_fkey";

alter table "public"."delivery_route_items" drop constraint "delivery_route_items_purchase_order_item_id_fkey";

alter table "public"."delivery_route_items" drop constraint "delivery_route_items_route_id_fkey";

alter table "public"."delivery_route_items" drop constraint "delivery_route_items_warehouse_id_fkey";

alter table "public"."delivery_route_items" drop constraint "fk_delivery_route_items_product";

alter table "public"."delivery_routes" drop constraint "delivery_routes_delivery_status_check";

alter table "public"."delivery_routes" drop constraint "delivery_routes_kitting_code_key";

alter table "public"."delivery_routes" drop constraint "delivery_routes_person_in_charge_id_fkey";

alter table "public"."delivery_routes" drop constraint "delivery_routes_warehouse_id_fkey";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_purchase_order_id_fkey";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_quality_check_status_check";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_received_by_fkey";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_reference_key";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_supplier_id_fkey";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_warehouse_id_fkey";

alter table "public"."inventory_transactions" drop constraint "inventory_transactions_created_by_fkey";

alter table "public"."inventory_transactions" drop constraint "inventory_transactions_transaction_type_check";

alter table "public"."inventory_transactions" drop constraint "inventory_transactions_warehouse_id_fkey";

alter table "public"."machine_refill_records" drop constraint "machine_refill_records_delivery_route_id_fkey";

alter table "public"."machine_refill_records" drop constraint "machine_refill_records_refilled_by_fkey";

alter table "public"."machine_refill_records" drop constraint "machine_refill_records_warehouse_id_fkey";

alter table "public"."ordering_triggers" drop constraint "fk_ordering_triggers_product";

alter table "public"."ordering_triggers" drop constraint "ordering_triggers_check";

alter table "public"."ordering_triggers" drop constraint "ordering_triggers_min_quantity_check";

alter table "public"."ordering_triggers" drop constraint "ordering_triggers_supplier_id_fkey";

alter table "public"."ordering_triggers" drop constraint "ordering_triggers_warehouse_id_fkey";

alter table "public"."pages" drop constraint "pages_slug_key";

alter table "public"."profiles" drop constraint "profiles_email_unique";

alter table "public"."profiles" drop constraint "profiles_id_fkey";

alter table "public"."purchase_order_items" drop constraint "fk_purchase_order_items_product";

alter table "public"."purchase_order_items" drop constraint "purchase_order_items_purchase_order_id_fkey";

alter table "public"."purchase_order_items" drop constraint "purchase_order_items_quantity_check";

alter table "public"."purchase_order_items" drop constraint "purchase_order_items_received_quantity_check";

alter table "public"."purchase_orders" drop constraint "purchase_orders_confirmed_by_fkey";

alter table "public"."purchase_orders" drop constraint "purchase_orders_created_by_fkey";

alter table "public"."purchase_orders" drop constraint "purchase_orders_deliver_to_warehouse_id_fkey";

alter table "public"."purchase_orders" drop constraint "purchase_orders_reference_key";

alter table "public"."purchase_orders" drop constraint "purchase_orders_status_check";

alter table "public"."purchase_orders" drop constraint "purchase_orders_supplier_id_fkey";

alter table "public"."role_page_perms" drop constraint "role_page_perms_page_id_fkey";

alter table "public"."role_page_perms" drop constraint "role_page_perms_perms_mask_check";

alter table "public"."roles" drop constraint "roles_slug_key";

alter table "public"."stock_adjustments" drop constraint "fk_stock_adjustments_product";

alter table "public"."stock_adjustments" drop constraint "stock_adjustments_adjusted_by_fkey";

alter table "public"."stock_adjustments" drop constraint "stock_adjustments_adjustment_type_check";

alter table "public"."stock_adjustments" drop constraint "stock_adjustments_warehouse_id_fkey";

alter table "public"."suppliers" drop constraint "suppliers_status_check";

alter table "public"."user_page_perms" drop constraint "user_page_perms_page_id_fkey";

alter table "public"."user_page_perms" drop constraint "user_page_perms_perms_mask_check";

alter table "public"."user_page_perms" drop constraint "user_page_perms_user_id_fkey";

alter table "public"."user_roles" drop constraint "user_roles_user_id_fkey";

alter table "public"."warehouse_stock" drop constraint "fk_warehouse_stock_product";

alter table "public"."warehouse_stock" drop constraint "warehouse_stock_quantity_check";

alter table "public"."warehouse_stock" drop constraint "warehouse_stock_warehouse_id_fkey";

alter table "public"."warehouse_stock" drop constraint "warehouse_stock_warehouse_id_product_id_batch_number_key";

alter table "public"."warehouses" drop constraint "warehouses_location_type_check";

alter table "public"."warehouses" drop constraint "warehouses_sub_warehouse_of_fkey";

alter table "public"."warehouses" drop constraint "warehouses_warehouse_type_check";

alter table "public"."products" drop constraint "products_price_check";

drop function if exists "public"."calculate_po_item_subtotal"();

drop function if exists "public"."grant_role_permissions_to_user"();

drop function if exists "public"."update_purchase_order_total"();

drop function if exists "public"."update_updated_at_column"();

alter table "public"."audit_logs" drop constraint "audit_logs_pkey";

alter table "public"."delivery_route_items" drop constraint "delivery_route_items_pkey";

alter table "public"."delivery_routes" drop constraint "delivery_routes_pkey";

alter table "public"."goods_receipt_notes" drop constraint "goods_receipt_notes_pkey";

alter table "public"."inventory_transactions" drop constraint "inventory_transactions_pkey";

alter table "public"."machine_refill_records" drop constraint "machine_refill_records_pkey";

alter table "public"."ordering_triggers" drop constraint "ordering_triggers_pkey";

alter table "public"."pages" drop constraint "pages_pkey";

alter table "public"."purchase_order_items" drop constraint "purchase_order_items_pkey";

alter table "public"."purchase_orders" drop constraint "purchase_orders_pkey";

alter table "public"."role_page_perms" drop constraint "role_page_perms_pkey";

alter table "public"."roles" drop constraint "roles_pkey";

alter table "public"."schema_migrations" drop constraint "schema_migrations_pkey";

alter table "public"."stock_adjustments" drop constraint "stock_adjustments_pkey";

alter table "public"."suppliers" drop constraint "suppliers_pkey";

alter table "public"."user_page_perms" drop constraint "user_page_perms_pkey";

alter table "public"."user_roles" drop constraint "user_roles_pkey";

alter table "public"."warehouse_stock" drop constraint "warehouse_stock_pkey";

alter table "public"."warehouses" drop constraint "warehouses_pkey";

drop index if exists "public"."audit_logs_pkey";

drop index if exists "public"."delivery_route_items_pkey";

drop index if exists "public"."delivery_routes_kitting_code_key";

drop index if exists "public"."delivery_routes_pkey";

drop index if exists "public"."goods_receipt_notes_pkey";

drop index if exists "public"."goods_receipt_notes_reference_key";

drop index if exists "public"."idx_audit_logs_created_at";

drop index if exists "public"."idx_audit_logs_user_id";

drop index if exists "public"."idx_delivery_routes_date";

drop index if exists "public"."idx_delivery_routes_person";

drop index if exists "public"."idx_delivery_routes_status";

drop index if exists "public"."idx_dr_items_po_item";

drop index if exists "public"."idx_dr_items_warehouse";

drop index if exists "public"."idx_grn_po";

drop index if exists "public"."idx_grn_warehouse";

drop index if exists "public"."idx_inv_trans_created";

drop index if exists "public"."idx_inv_trans_product";

drop index if exists "public"."idx_inv_trans_type";

drop index if exists "public"."idx_inv_trans_warehouse";

drop index if exists "public"."idx_ordering_triggers_product";

drop index if exists "public"."idx_ordering_triggers_warehouse";

drop index if exists "public"."idx_pages_slug";

drop index if exists "public"."idx_po_items_order";

drop index if exists "public"."idx_po_items_product";

drop index if exists "public"."idx_profiles_email";

drop index if exists "public"."idx_profiles_role_slug";

drop index if exists "public"."idx_purchase_orders_reference";

drop index if exists "public"."idx_purchase_orders_status";

drop index if exists "public"."idx_purchase_orders_supplier";

drop index if exists "public"."idx_refill_machine";

drop index if exists "public"."idx_refill_product";

drop index if exists "public"."idx_refill_route";

drop index if exists "public"."idx_refill_warehouse";

drop index if exists "public"."idx_role_page_perms_page_id";

drop index if exists "public"."idx_role_page_perms_role_id";

drop index if exists "public"."idx_roles_slug";

drop index if exists "public"."idx_route_items_route";

drop index if exists "public"."idx_stock_adjustments_date";

drop index if exists "public"."idx_stock_adjustments_type";

drop index if exists "public"."idx_stock_adjustments_warehouse";

drop index if exists "public"."idx_suppliers_company_name";

drop index if exists "public"."idx_suppliers_status";

drop index if exists "public"."idx_user_page_perms_page_id";

drop index if exists "public"."idx_user_page_perms_user_id";

drop index if exists "public"."idx_user_roles_role_id";

drop index if exists "public"."idx_user_roles_user_id";

drop index if exists "public"."idx_warehouse_stock_expiry";

drop index if exists "public"."idx_warehouse_stock_product";

drop index if exists "public"."idx_warehouse_stock_warehouse";

drop index if exists "public"."idx_warehouses_is_preferred";

drop index if exists "public"."idx_warehouses_name";

drop index if exists "public"."inventory_transactions_pkey";

drop index if exists "public"."machine_refill_records_pkey";

drop index if exists "public"."ordering_triggers_pkey";

drop index if exists "public"."pages_pkey";

drop index if exists "public"."pages_slug_key";

drop index if exists "public"."profiles_email_unique";

drop index if exists "public"."purchase_order_items_pkey";

drop index if exists "public"."purchase_orders_pkey";

drop index if exists "public"."purchase_orders_reference_key";

drop index if exists "public"."role_page_perms_pkey";

drop index if exists "public"."roles_pkey";

drop index if exists "public"."roles_slug_key";

drop index if exists "public"."schema_migrations_pkey";

drop index if exists "public"."stock_adjustments_pkey";

drop index if exists "public"."suppliers_pkey";

drop index if exists "public"."user_page_perms_pkey";

drop index if exists "public"."user_roles_pkey";

drop index if exists "public"."warehouse_stock_pkey";

drop index if exists "public"."warehouse_stock_warehouse_id_product_id_batch_number_key";

drop index if exists "public"."warehouses_pkey";

drop table "public"."audit_logs";

drop table "public"."delivery_route_items";

drop table "public"."delivery_routes";

drop table "public"."goods_receipt_notes";

drop table "public"."inventory_transactions";

drop table "public"."machine_refill_records";

drop table "public"."ordering_triggers";

drop table "public"."pages";

drop table "public"."purchase_order_items";

drop table "public"."purchase_orders";

drop table "public"."role_page_perms";

drop table "public"."roles";

drop table "public"."schema_migrations";

drop table "public"."stock_adjustments";

drop table "public"."suppliers";

drop table "public"."user_page_perms";

drop table "public"."user_roles";

drop table "public"."warehouse_stock";

drop table "public"."warehouses";


  create table "public"."device_status" (
    "id" bigint generated by default as identity not null,
    "deviceid" text not null,
    "status" text not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "public"."logs" (
    "id" bigint generated by default as identity not null,
    "created_at" timestamp with time zone not null default now(),
    "logs" text,
    "machineid" text
      );


alter table "public"."products" drop column "selling_price";

alter table "public"."profiles" drop column "avatar_url";

alter table "public"."profiles" drop column "full_name";

alter table "public"."profiles" drop column "phone";

alter table "public"."profiles" drop column "role_slug";

alter table "public"."profiles" drop column "updated_at";

alter table "public"."profiles" add column "role" text not null default 'admin'::text;

alter table "public"."profiles" add column "user_id" uuid not null;

alter table "public"."profiles" alter column "created_at" set not null;

alter table "public"."profiles" alter column "id" set default gen_random_uuid();

drop sequence if exists "public"."audit_logs_id_seq";

drop sequence if exists "public"."pages_id_seq";

drop sequence if exists "public"."roles_id_seq";

CREATE UNIQUE INDEX device_status_pkey ON public.device_status USING btree (id);

CREATE UNIQUE INDEX logs_pkey ON public.logs USING btree (id);

CREATE UNIQUE INDEX profiles_user_id_key ON public.profiles USING btree (user_id);

alter table "public"."device_status" add constraint "device_status_pkey" PRIMARY KEY using index "device_status_pkey";

alter table "public"."logs" add constraint "logs_pkey" PRIMARY KEY using index "logs_pkey";

alter table "public"."device_status" add constraint "device_status_deviceid_fkey" FOREIGN KEY (deviceid) REFERENCES public.vending_machines(machine_id) not valid;

alter table "public"."device_status" validate constraint "device_status_deviceid_fkey";

alter table "public"."profiles" add constraint "profiles_role_check" CHECK ((role = ANY (ARRAY['admin'::text, 'manager'::text]))) not valid;

alter table "public"."profiles" validate constraint "profiles_role_check";

alter table "public"."profiles" add constraint "profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_user_id_key" UNIQUE using index "profiles_user_id_key";

alter table "public"."slots" add constraint "slots_vending_machine_id_fkey" FOREIGN KEY (vending_machine_id) REFERENCES public.vending_machines(id) ON DELETE CASCADE not valid;

alter table "public"."slots" validate constraint "slots_vending_machine_id_fkey";

alter table "public"."products" add constraint "products_price_check" CHECK (((price)::double precision >= (0)::double precision)) not valid;

alter table "public"."products" validate constraint "products_price_check";

grant delete on table "public"."device_status" to "anon";

grant insert on table "public"."device_status" to "anon";

grant references on table "public"."device_status" to "anon";

grant select on table "public"."device_status" to "anon";

grant trigger on table "public"."device_status" to "anon";

grant truncate on table "public"."device_status" to "anon";

grant update on table "public"."device_status" to "anon";

grant delete on table "public"."device_status" to "authenticated";

grant insert on table "public"."device_status" to "authenticated";

grant references on table "public"."device_status" to "authenticated";

grant select on table "public"."device_status" to "authenticated";

grant trigger on table "public"."device_status" to "authenticated";

grant truncate on table "public"."device_status" to "authenticated";

grant update on table "public"."device_status" to "authenticated";

grant delete on table "public"."device_status" to "service_role";

grant insert on table "public"."device_status" to "service_role";

grant references on table "public"."device_status" to "service_role";

grant select on table "public"."device_status" to "service_role";

grant trigger on table "public"."device_status" to "service_role";

grant truncate on table "public"."device_status" to "service_role";

grant update on table "public"."device_status" to "service_role";

grant delete on table "public"."logs" to "anon";

grant insert on table "public"."logs" to "anon";

grant references on table "public"."logs" to "anon";

grant select on table "public"."logs" to "anon";

grant trigger on table "public"."logs" to "anon";

grant truncate on table "public"."logs" to "anon";

grant update on table "public"."logs" to "anon";

grant delete on table "public"."logs" to "authenticated";

grant insert on table "public"."logs" to "authenticated";

grant references on table "public"."logs" to "authenticated";

grant select on table "public"."logs" to "authenticated";

grant trigger on table "public"."logs" to "authenticated";

grant truncate on table "public"."logs" to "authenticated";

grant update on table "public"."logs" to "authenticated";

grant delete on table "public"."logs" to "service_role";

grant insert on table "public"."logs" to "service_role";

grant references on table "public"."logs" to "service_role";

grant select on table "public"."logs" to "service_role";

grant trigger on table "public"."logs" to "service_role";

grant truncate on table "public"."logs" to "service_role";

grant update on table "public"."logs" to "service_role";


