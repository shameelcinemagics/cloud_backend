-- prerequisites
create extension if not exists "pgcrypto" with schema public;

create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.grant_role_permissions_to_user()
returns trigger
language plpgsql
as $$
begin
  insert into public.user_page_perms (user_id, page_id, perms_mask, created_at, updated_at)
  select new.user_id, rpp.page_id, rpp.perms_mask, now(), now()
  from public.role_page_perms rpp
  where rpp.role_id = new.role_id
  on conflict (user_id, page_id) do update
    set perms_mask = excluded.perms_mask,
        updated_at = now();
  return new;
end;
$$;

create or replace function public.calculate_po_item_subtotal()
returns trigger
language plpgsql
as $$
begin
  new.subtotal := coalesce(new.quantity, 0) * coalesce(new.unit_price, 0);
  return new;
end;
$$;

create or replace function public.update_purchase_order_total()
returns trigger
language plpgsql
as $$
declare
  v_total numeric(10,3);
begin
  select coalesce(sum(subtotal), 0) into v_total
  from public.purchase_order_items
  where purchase_order_id = coalesce(new.purchase_order_id, old.purchase_order_id);

  update public.purchase_orders
  set total_amount = v_total,
      updated_at = now()
  where id = coalesce(new.purchase_order_id, old.purchase_order_id);

  return new;
end;
$$;

-- #1 audit_logs
create table public.audit_logs (
  id bigserial not null,
  user_id uuid null,
  table_name text not null,
  action text not null,
  old_data jsonb null,
  new_data jsonb null,
  created_at timestamp with time zone null default now(),
  constraint audit_logs_pkey primary key (id),
  constraint audit_logs_user_id_fkey foreign key (user_id) references auth.users (id) on delete set null
) tablespace pg_default;

create index if not exists idx_audit_logs_user_id on public.audit_logs using btree (user_id) tablespace pg_default;
create index if not exists idx_audit_logs_created_at on public.audit_logs using btree (created_at) tablespace pg_default;

-- #2 pages
create table public.pages (
  id bigserial not null,
  slug text not null,
  label text not null,
  description text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint pages_pkey primary key (id),
  constraint pages_slug_key unique (slug)
) tablespace pg_default;

create index if not exists idx_pages_slug on public.pages using btree (slug) tablespace pg_default;
create trigger update_pages_updated_at before update on pages for each row execute function update_updated_at_column ();

-- #3 roles
create table public.roles (
  id bigserial not null,
  slug text not null,
  label text not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint roles_pkey primary key (id),
  constraint roles_slug_key unique (slug)
) tablespace pg_default;

create index if not exists idx_roles_slug on public.roles using btree (slug) tablespace pg_default;
create trigger update_roles_updated_at before update on roles for each row execute function update_updated_at_column ();

-- #4 role_page_perms
create table public.role_page_perms (
  role_id bigint not null,
  page_id bigint not null,
  perms_mask integer not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint role_page_perms_pkey primary key (role_id, page_id),
  constraint role_page_perms_page_id_fkey foreign key (page_id) references pages (id) on delete cascade,
  constraint role_page_perms_perms_mask_check check (perms_mask >= 0 and perms_mask <= 15)
) tablespace pg_default;

create index if not exists idx_role_page_perms_role_id on public.role_page_perms using btree (role_id) tablespace pg_default;
create index if not exists idx_role_page_perms_page_id on public.role_page_perms using btree (page_id) tablespace pg_default;
create trigger update_role_page_perms_updated_at before update on role_page_perms for each row execute function update_updated_at_column ();

-- #5 user_roles
create table public.user_roles (
  user_id uuid not null,
  role_id bigint not null,
  created_at timestamp with time zone null default now(),
  constraint user_roles_pkey primary key (user_id),
  constraint user_roles_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
) tablespace pg_default;

create index if not exists idx_user_roles_user_id on public.user_roles using btree (user_id) tablespace pg_default;
create index if not exists idx_user_roles_role_id on public.user_roles using btree (role_id) tablespace pg_default;
create trigger trigger_grant_role_permissions after insert on user_roles for each row execute function grant_role_permissions_to_user ();

-- #6 user_page_perms
create table public.user_page_perms (
  user_id uuid not null,
  page_id bigint not null,
  perms_mask integer not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint user_page_perms_pkey primary key (user_id, page_id),
  constraint user_page_perms_page_id_fkey foreign key (page_id) references pages (id) on delete cascade,
  constraint user_page_perms_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade,
  constraint user_page_perms_perms_mask_check check (perms_mask >= 0 and perms_mask <= 15)
) tablespace pg_default;

create index if not exists idx_user_page_perms_user_id on public.user_page_perms using btree (user_id) tablespace pg_default;
create index if not exists idx_user_page_perms_page_id on public.user_page_perms using btree (page_id) tablespace pg_default;
create trigger update_user_page_perms_updated_at before update on user_page_perms for each row execute function update_updated_at_column ();

-- #7 profiles
create table public.profiles (
  id uuid not null,
  email text not null,
  full_name text null,
  avatar_url text null,
  phone text null,
  role_slug text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint profiles_pkey primary key (id),
  constraint profiles_email_unique unique (email),
  constraint profiles_id_fkey foreign key (id) references auth.users (id) on delete cascade
) tablespace pg_default;

create index if not exists idx_profiles_email on public.profiles using btree (email) tablespace pg_default;
create index if not exists idx_profiles_role_slug on public.profiles using btree (role_slug) tablespace pg_default;
create trigger update_profiles_updated_at before update on profiles for each row execute function update_updated_at_column ();

-- #8 suppliers
create table public.suppliers (
  id uuid not null default gen_random_uuid (),
  company_name text not null,
  email text null,
  company_registration text null,
  phone_number text null,
  fax_number text null,
  bank_name text null,
  bank_account_no text null,
  swift_code text null,
  company_intro text null,
  country text null default 'Kuwait'::text,
  state_province text null,
  address_line1 text null,
  address_line2 text null,
  address_line3 text null,
  postal_zip_code text null,
  city text null,
  contact_person text null,
  website text null,
  tax_id text null,
  payment_terms text null,
  status text null default 'active'::text,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  country_code text null default '+965'::text,
  constraint suppliers_pkey primary key (id),
  constraint suppliers_status_check check (status = any (array['active'::text, 'inactive'::text]))
) tablespace pg_default;

create index if not exists idx_suppliers_company_name on public.suppliers using btree (company_name) tablespace pg_default;
create index if not exists idx_suppliers_status on public.suppliers using btree (status) tablespace pg_default;
create trigger update_suppliers_updated_at before update on suppliers for each row execute function update_updated_at_column ();

-- #9 media
create table public.media (
  id bigint generated by default as identity not null,
  title text not null,
  type text not null,
  url text not null,
  created_at timestamp with time zone not null default now(),
  constraint media_pkey primary key (id)
) tablespace pg_default;

-- #10 products
create table public.products (
  id uuid not null default gen_random_uuid (),
  name text not null,
  price numeric not null,
  image_url text null,
  created_at timestamp with time zone not null default now(),
  ingredients text null,
  health_rating integer null,
  calories numeric null,
  fat numeric null,
  carbs numeric null,
  protein numeric null,
  sodium numeric null,
  category text null,
  "partNo" numeric null,
  selling_price numeric null,
  constraint products_pkey primary key (id),
  constraint products_partno_key unique ("partNo"),
  constraint products_health_rating_range check ((health_rating is null) or (health_rating >= 1 and health_rating <= 3)),
  constraint products_price_check check ((price)::double precision >= ((0)::numeric)::double precision)
) tablespace pg_default;

-- #11 warehouses
create table public.warehouses (
  id uuid not null default gen_random_uuid (),
  name text not null,
  warehouse_image_url text null,
  location_coordinate text null,
  location_name text null,
  address text null,
  sub_warehouse_of uuid null,
  ignore_stock_quantity_during_restock boolean null default false,
  is_preferred boolean null default false,
  phone text null,
  email text null,
  warehouse_type text null,
  location_type text null,
  management_types text[] null default '{}'::text[],
  external_id text null,
  description text null,
  working_days text[] null default '{}'::text[],
  working_hours_from time without time zone null,
  working_hours_to time without time zone null,
  has_time_interval boolean null default false,
  custom_room text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint warehouses_pkey primary key (id),
  constraint warehouses_sub_warehouse_of_fkey foreign key (sub_warehouse_of) references warehouses (id) on delete set null,
  constraint warehouses_location_type_check check (location_type = any (array['cash_room'::text, 'client_location'::text, 'standalone'::text])),
  constraint warehouses_warehouse_type_check check (warehouse_type = any (array['main'::text, 'regional'::text, 'distribution'::text, 'cold_storage'::text, 'other'::text]))
) tablespace pg_default;

create index if not exists idx_warehouses_name on public.warehouses using btree (name) tablespace pg_default;
create index if not exists idx_warehouses_is_preferred on public.warehouses using btree (is_preferred) tablespace pg_default;
create trigger update_warehouses_updated_at before update on warehouses for each row execute function update_updated_at_column ();

-- #12 vending_machines
create table public.vending_machines (
  id uuid not null default gen_random_uuid (),
  machine_id text not null,
  location text not null,
  status text not null default 'active'::text,
  created_at timestamp with time zone not null default now(),
  constraint vending_machines_pkey primary key (id),
  constraint vending_machines_machine_id_key unique (machine_id),
  constraint vending_machines_status_check check (status = any (array['active'::text, 'inactive'::text, 'maintenance'::text]))
) tablespace pg_default;

-- #13 warehouse_stock
create table public.warehouse_stock (
  id uuid not null default gen_random_uuid (),
  warehouse_id uuid not null,
  product_id uuid not null,
  quantity integer not null default 0,
  min_stock_level integer null default 0,
  max_stock_level integer null,
  unit_cost numeric(10, 3) null default 0,
  expiry_date date null,
  batch_number text null,
  last_purchase_date date null,
  last_purchase_price numeric(10, 3) null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint warehouse_stock_pkey primary key (id),
  constraint warehouse_stock_warehouse_id_product_id_batch_number_key unique (warehouse_id, product_id, batch_number),
  constraint fk_warehouse_stock_product foreign key (product_id) references products (id) on delete cascade,
  constraint warehouse_stock_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete cascade,
  constraint warehouse_stock_quantity_check check (quantity >= 0)
) tablespace pg_default;

create index if not exists idx_warehouse_stock_warehouse on public.warehouse_stock using btree (warehouse_id) tablespace pg_default;
create index if not exists idx_warehouse_stock_product on public.warehouse_stock using btree (product_id) tablespace pg_default;
create index if not exists idx_warehouse_stock_expiry on public.warehouse_stock using btree (expiry_date) tablespace pg_default;
create trigger update_warehouse_stock_updated_at before update on warehouse_stock for each row execute function update_updated_at_column ();

-- #14 ordering_triggers
create table public.ordering_triggers (
  id uuid not null default gen_random_uuid (),
  name text not null,
  product_id uuid not null,
  warehouse_id uuid not null,
  min_quantity integer not null,
  max_quantity integer not null,
  unit_of_measure text null default 'Units'::text,
  auto_order_enabled boolean null default false,
  supplier_id uuid null,
  last_triggered_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint ordering_triggers_pkey primary key (id),
  constraint fk_ordering_triggers_product foreign key (product_id) references products (id) on delete cascade,
  constraint ordering_triggers_supplier_id_fkey foreign key (supplier_id) references suppliers (id) on delete set null,
  constraint ordering_triggers_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete cascade,
  constraint ordering_triggers_check check ((max_quantity >= min_quantity)),
  constraint ordering_triggers_min_quantity_check check ((min_quantity >= 0))
) tablespace pg_default;

create index if not exists idx_ordering_triggers_product on public.ordering_triggers using btree (product_id) tablespace pg_default;
create index if not exists idx_ordering_triggers_warehouse on public.ordering_triggers using btree (warehouse_id) tablespace pg_default;
create trigger update_ordering_triggers_updated_at before update on ordering_triggers for each row execute function update_updated_at_column ();

-- #15 purchase_orders
create table public.purchase_orders (
  id uuid not null default gen_random_uuid (),
  reference text not null,
  supplier_id uuid null,
  vendor_reference text null,
  buyer_name text null,
  delivery_address text null,
  currency text null default 'KWD'::text,
  order_deadline timestamp with time zone null,
  expected_arrival timestamp with time zone null,
  deliver_to_warehouse_id uuid null,
  total_amount numeric(10, 3) null default 0,
  status text null default 'draft'::text,
  terms_and_conditions text null,
  source_document text null,
  created_by uuid null,
  confirmed_by uuid null,
  confirmation_date timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint purchase_orders_pkey primary key (id),
  constraint purchase_orders_reference_key unique (reference),
  constraint purchase_orders_created_by_fkey foreign key (created_by) references auth.users (id) on delete set null,
  constraint purchase_orders_deliver_to_warehouse_id_fkey foreign key (deliver_to_warehouse_id) references warehouses (id) on delete set null,
  constraint purchase_orders_confirmed_by_fkey foreign key (confirmed_by) references auth.users (id) on delete set null,
  constraint purchase_orders_supplier_id_fkey foreign key (supplier_id) references suppliers (id) on delete set null,
  constraint purchase_orders_status_check check (status = any (array['draft'::text, 'locked'::text, 'sent'::text, 'received'::text, 'cancelled'::text]))
) tablespace pg_default;

create index if not exists idx_purchase_orders_reference on public.purchase_orders using btree (reference) tablespace pg_default;
create index if not exists idx_purchase_orders_supplier on public.purchase_orders using btree (supplier_id) tablespace pg_default;
create index if not exists idx_purchase_orders_status on public.purchase_orders using btree (status) tablespace pg_default;
create trigger update_purchase_orders_updated_at before update on purchase_orders for each row execute function update_updated_at_column ();

-- #16 purchase_order_items
create table public.purchase_order_items (
  id uuid not null default gen_random_uuid (),
  purchase_order_id uuid not null,
  product_id uuid not null,
  quantity integer not null,
  unit_price numeric(10, 3) not null,
  created_at timestamp with time zone null default now(),
  received_quantity integer null default 0,
  notes text null,
  updated_at timestamp with time zone null default now(),
  subtotal numeric(10, 3) null default 0,
  constraint purchase_order_items_pkey primary key (id),
  constraint fk_purchase_order_items_product foreign key (product_id) references products (id) on delete restrict,
  constraint purchase_order_items_purchase_order_id_fkey foreign key (purchase_order_id) references purchase_orders (id) on delete cascade,
  constraint purchase_order_items_quantity_check check ((quantity > 0)),
  constraint purchase_order_items_received_quantity_check check ((received_quantity >= 0))
) tablespace pg_default;

create index if not exists idx_po_items_order on public.purchase_order_items using btree (purchase_order_id) tablespace pg_default;
create index if not exists idx_po_items_product on public.purchase_order_items using btree (product_id) tablespace pg_default;
create trigger calculate_po_item_subtotal_trigger before insert or update of quantity, unit_price on purchase_order_items for each row execute function calculate_po_item_subtotal ();
create trigger update_po_total_on_item_change after insert or delete or update on purchase_order_items for each row execute function update_purchase_order_total ();
create trigger update_purchase_order_items_updated_at before update on purchase_order_items for each row execute function update_updated_at_column ();

-- #17 delivery_routes
create table public.delivery_routes (
  id uuid not null default gen_random_uuid (),
  name text not null,
  description text null,
  person_in_charge_id uuid null,
  warehouse_id uuid null,
  machines uuid[] null default '{}'::uuid[],
  delivery_status text null default 'pending'::text,
  kitting_code text null,
  route_date date null default current_date,
  started_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint delivery_routes_pkey primary key (id),
  constraint delivery_routes_kitting_code_key unique (kitting_code),
  constraint delivery_routes_person_in_charge_id_fkey foreign key (person_in_charge_id) references auth.users (id) on delete set null,
  constraint delivery_routes_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete set null,
  constraint delivery_routes_delivery_status_check check (delivery_status = any (array['pending'::text, 'in_route'::text, 'completed'::text, 'cancelled'::text]))
) tablespace pg_default;

create index if not exists idx_delivery_routes_status on public.delivery_routes using btree (delivery_status) tablespace pg_default;
create index if not exists idx_delivery_routes_date on public.delivery_routes using btree (route_date) tablespace pg_default;
create index if not exists idx_delivery_routes_person on public.delivery_routes using btree (person_in_charge_id) tablespace pg_default;
create trigger update_delivery_routes_updated_at before update on delivery_routes for each row execute function update_updated_at_column ();

-- #18 delivery_route_items
create table public.delivery_route_items (
  id uuid not null default gen_random_uuid (),
  delivery_route_id uuid not null,
  product_id uuid not null,
  product_vpn text null,
  quantity_to_bring integer null default 0,
  quantity_to_remove integer null default 0,
  machine_id uuid null,
  created_at timestamp with time zone null default now(),
  purchase_order_item_id uuid null,
  warehouse_id uuid null,
  received_quantity integer null default 0,
  batch_number text null,
  expiry_date date null,
  manufacturing_date date null,
  constraint delivery_route_items_pkey primary key (id),
  constraint delivery_route_items_purchase_order_item_id_fkey foreign key (purchase_order_item_id) references purchase_order_items (id) on delete set null,
  constraint delivery_route_items_route_id_fkey foreign key (delivery_route_id) references delivery_routes (id) on delete cascade,
  constraint delivery_route_items_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete set null,
  constraint fk_delivery_route_items_product foreign key (product_id) references products (id) on delete cascade
) tablespace pg_default;

create index if not exists idx_route_items_route on public.delivery_route_items using btree (delivery_route_id) tablespace pg_default;
create index if not exists idx_dr_items_po_item on public.delivery_route_items using btree (purchase_order_item_id) tablespace pg_default;
create index if not exists idx_dr_items_warehouse on public.delivery_route_items using btree (warehouse_id) tablespace pg_default;

-- #19 goods_receipt_notes
create table public.goods_receipt_notes (
  id uuid not null default gen_random_uuid (),
  reference text not null,
  purchase_order_id uuid null,
  warehouse_id uuid not null,
  supplier_id uuid null,
  received_date timestamp with time zone null default now(),
  received_by uuid null,
  quality_check_status text null default 'pending'::text,
  notes text null,
  created_at timestamp with time zone null default now(),
  constraint goods_receipt_notes_pkey primary key (id),
  constraint goods_receipt_notes_reference_key unique (reference),
  constraint goods_receipt_notes_received_by_fkey foreign key (received_by) references auth.users (id) on delete set null,
  constraint goods_receipt_notes_purchase_order_id_fkey foreign key (purchase_order_id) references purchase_orders (id) on delete set null,
  constraint goods_receipt_notes_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete cascade,
  constraint goods_receipt_notes_supplier_id_fkey foreign key (supplier_id) references suppliers (id) on delete set null,
  constraint goods_receipt_notes_quality_check_status_check check (quality_check_status = any (array['pending'::text, 'passed'::text, 'failed'::text, 'partial'::text]))
) tablespace pg_default;

create index if not exists idx_grn_po on public.goods_receipt_notes using btree (purchase_order_id) tablespace pg_default;
create index if not exists idx_grn_warehouse on public.goods_receipt_notes using btree (warehouse_id) tablespace pg_default;

-- #20 inventory_transactions
create table public.inventory_transactions (
  id uuid not null default gen_random_uuid (),
  warehouse_id uuid null,
  product_id uuid null,
  transaction_type text not null,
  quantity_change integer not null,
  quantity_before integer not null,
  quantity_after integer not null,
  reference_type text null,
  reference_id uuid null,
  batch_number text null,
  expiry_date date null,
  notes text null,
  created_by uuid null,
  created_at timestamp with time zone null default now(),
  constraint inventory_transactions_pkey primary key (id),
  constraint inventory_transactions_created_by_fkey foreign key (created_by) references auth.users (id) on delete set null,
  constraint inventory_transactions_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete cascade,
  constraint inventory_transactions_transaction_type_check check (transaction_type = any (array['purchase_receipt'::text, 'machine_refill'::text, 'adjustment'::text, 'expired'::text, 'damaged'::text, 'return'::text]))
) tablespace pg_default;

create index if not exists idx_inv_trans_warehouse on public.inventory_transactions using btree (warehouse_id) tablespace pg_default;
create index if not exists idx_inv_trans_product on public.inventory_transactions using btree (product_id) tablespace pg_default;
create index if not exists idx_inv_trans_type on public.inventory_transactions using btree (transaction_type) tablespace pg_default;
create index if not exists idx_inv_trans_created on public.inventory_transactions using btree (created_at) tablespace pg_default;

-- #21 machine_media
create table public.machine_media (
  id uuid not null default gen_random_uuid (),
  vending_machine_id uuid null,
  media_id bigint null,
  created_at timestamp with time zone null default now(),
  constraint machine_media_pkey primary key (id),
  constraint machine_media_media_id_fkey foreign key (media_id) references media (id) on delete cascade,
  constraint machine_media_vending_machine_id_fkey foreign key (vending_machine_id) references vending_machines (id) on delete cascade
) tablespace pg_default;

-- #22 machine_refill_records
create table public.machine_refill_records (
  id uuid not null default gen_random_uuid (),
  delivery_route_id uuid null,
  vending_machine_id uuid null,
  warehouse_id uuid null,
  slot_id uuid null,
  product_id uuid null,
  quantity_added integer null default 0,
  quantity_removed integer null default 0,
  old_quantity integer null default 0,
  new_quantity integer null default 0,
  expiry_date date null,
  batch_number text null,
  notes text null,
  refilled_by uuid null,
  refilled_at timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  constraint machine_refill_records_pkey primary key (id),
  constraint machine_refill_records_delivery_route_id_fkey foreign key (delivery_route_id) references delivery_routes (id) on delete cascade,
  constraint machine_refill_records_refilled_by_fkey foreign key (refilled_by) references auth.users (id) on delete set null,
  constraint machine_refill_records_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete set null
) tablespace pg_default;

create index if not exists idx_refill_route on public.machine_refill_records using btree (delivery_route_id) tablespace pg_default;
create index if not exists idx_refill_machine on public.machine_refill_records using btree (vending_machine_id) tablespace pg_default;
create index if not exists idx_refill_warehouse on public.machine_refill_records using btree (warehouse_id) tablespace pg_default;
create index if not exists idx_refill_product on public.machine_refill_records using btree (product_id) tablespace pg_default;

-- #23 sales
create table public.sales (
  id uuid not null default gen_random_uuid (),
  vending_machine_id uuid not null,
  product_id uuid not null,
  slot_number integer not null,
  quantity integer not null default 1,
  sold_at timestamp with time zone not null default now(),
  unit_price numeric(10, 3) not null,
  constraint sales_pkey primary key (id),
  constraint sales_product_id_fkey foreign key (product_id) references products (id) on delete cascade,
  constraint sales_vending_machine_id_fkey foreign key (vending_machine_id) references vending_machines (id) on delete cascade,
  constraint sales_quantity_check check ((quantity > 0)),
  constraint sales_unit_price_nonnegative check (((unit_price is null) or (unit_price >= (0)::numeric)))
) tablespace pg_default;

-- #24 slots
create table public.slots (
  id uuid not null default gen_random_uuid (),
  vending_machine_id uuid not null,
  slot_number integer not null,
  product_id uuid null,
  quantity integer not null default 0,
  max_capacity integer not null default 10,
  created_at timestamp with time zone not null default now(),
  custom_price numeric null,
  constraint slots_pkey primary key (id),
  constraint slots_vending_machine_id_slot_number_key unique (vending_machine_id, slot_number),
  constraint slots_product_id_fkey foreign key (product_id) references products (id) on delete set null,
  constraint slots_max_capacity_check check ((max_capacity > 0)),
  constraint slots_quantity_check check ((quantity >= 0)),
  constraint slots_slot_number_check check ((slot_number > 0))
) tablespace pg_default;

-- #25 stock_adjustments
create table public.stock_adjustments (
  id uuid not null default gen_random_uuid (),
  warehouse_id uuid not null,
  product_id uuid not null,
  adjustment_date date null default current_date,
  adjustment_type text not null,
  quantity integer not null,
  previous_quantity integer not null,
  new_quantity integer not null,
  unit_price numeric(10, 3) null,
  total_price numeric(10, 3) null,
  remark text null,
  source_document text null,
  adjusted_by uuid null,
  created_at timestamp with time zone null default now(),
  constraint stock_adjustments_pkey primary key (id),
  constraint fk_stock_adjustments_product foreign key (product_id) references products (id) on delete cascade,
  constraint stock_adjustments_adjusted_by_fkey foreign key (adjusted_by) references auth.users (id) on delete set null,
  constraint stock_adjustments_warehouse_id_fkey foreign key (warehouse_id) references warehouses (id) on delete cascade,
  constraint stock_adjustments_adjustment_type_check check (adjustment_type = any (array['purchase'::text, 'damage'::text, 'expired'::text, 'lost'::text, 'extra_bonus'::text, 'returned_to_supplier'::text, 'claim_to_customer'::text, 'pick_up_to_transit'::text, 'return_from_transit'::text, 'manual_adjustment'::text]))
) tablespace pg_default;

create index if not exists idx_stock_adjustments_warehouse on public.stock_adjustments using btree (warehouse_id) tablespace pg_default;
create index if not exists idx_stock_adjustments_date on public.stock_adjustments using btree (adjustment_date) tablespace pg_default;
create index if not exists idx_stock_adjustments_type on public.stock_adjustments using btree (adjustment_type) tablespace pg_default;

-- #26 transactions
create table public.transactions (
  id bigint generated by default as identity not null,
  "transationId" text not null,
  product text not null,
  status text not null,
  created_at timestamp with time zone not null default now(),
  machine text not null,
  constraint transactions_pkey primary key (id)
) tablespace pg_default;

-- #27 schema_migrations
create table public.schema_migrations (
  version text not null,
  applied_at timestamp with time zone null default now(),
  description text null,
  constraint schema_migrations_pkey primary key (version)
) tablespace pg_default;
