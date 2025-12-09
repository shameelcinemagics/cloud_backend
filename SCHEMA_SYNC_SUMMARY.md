# Schema Synchronization Summary

## 🎯 Overview

This document summarizes the schema synchronization between **Production** and **Development** databases.

Based on your production TypeScript types (`Vendit_Cloud/src/integrations/supabase/types.ts`), I've identified missing tables and created a comprehensive migration to sync both environments.

---

## 📊 Missing Tables from Production (Now Added)

### 1. **`products`** - Product Catalog
Main product catalog with nutritional information and pricing.

**Columns:**
- `id` (UUID) - Primary key
- `name` (TEXT) - Product name
- `price` (TEXT) - Price (stored as text for currency flexibility)
- `category` (TEXT) - Product category
- `image_url` (TEXT) - URL to product image
- `ingredients` (TEXT) - Ingredient list
- `health_rating` (INTEGER) - Health rating 0-5
- `calories`, `fat`, `carbs`, `protein`, `sodium` (NUMERIC) - Nutritional info
- `created_at` (TIMESTAMPTZ) - Creation timestamp

**Indexes:**
- `idx_products_name` - Fast name lookups
- `idx_products_category` - Category filtering
- `idx_products_health_rating` - Health rating queries
- `idx_products_created_at` - Sort by creation date

---

### 2. **`vending_machines`** - Machine Inventory
Vending machine records with status and location.

**Columns:**
- `id` (UUID) - Primary key
- `machine_id` (TEXT UNIQUE) - External machine ID
- `location` (TEXT) - Machine location
- `status` (TEXT) - Status: active, inactive, maintenance, offline
- `created_at` (TIMESTAMPTZ) - Creation timestamp

**Indexes:**
- `idx_vending_machines_machine_id` - Machine ID lookups
- `idx_vending_machines_status` - Status filtering
- `idx_vending_machines_location` - Location queries

---

### 3. **`slots`** - Vending Machine Slots
Individual slots within vending machines.

**Columns:**
- `id` (UUID) - Primary key
- `vending_machine_id` (UUID FK) - References `vending_machines.id`
- `slot_number` (INTEGER) - Slot number within machine
- `product_id` (UUID FK) - References `products.id`
- `quantity` (INTEGER) - Current quantity
- `max_capacity` (INTEGER) - Maximum capacity
- `created_at` (TIMESTAMPTZ) - Creation timestamp
- **UNIQUE:** `(vending_machine_id, slot_number)`

**Indexes:**
- `idx_slots_vending_machine` - Machine lookups
- `idx_slots_product` - Product queries
- `idx_slots_quantity_low` - Partial index for low stock (qty <= 3)

---

### 4. **`machine_products`** - Products Available per Machine
Links products to machines with machine-specific pricing.

**Columns:**
- `id` (UUID) - Primary key
- `vending_machine_id` (UUID FK) - References `vending_machines.id`
- `product_id` (UUID FK) - References `products.id`
- `price` (NUMERIC) - Machine-specific price
- `active` (BOOLEAN) - Whether product is active in this machine
- `created_at`, `updated_at` (TIMESTAMPTZ) - Timestamps
- **UNIQUE:** `(vending_machine_id, product_id)`

**Indexes:**
- `idx_machine_products_machine` - Machine queries
- `idx_machine_products_product` - Product queries
- `idx_machine_products_active` - Active products filtering

---

### 5. **`sales`** - Transaction History
Complete sales transaction history.

**Columns:**
- `id` (UUID) - Primary key
- `vending_machine_id` (UUID FK) - References `vending_machines.id`
- `product_id` (UUID FK) - References `products.id`
- `slot_number` (INTEGER) - Slot used for sale
- `quantity` (INTEGER) - Quantity sold
- `unit_price` (NUMERIC) - Price per unit
- `sold_at` (TIMESTAMPTZ) - Sale timestamp

**Indexes:**
- `idx_sales_vending_machine` - Machine queries
- `idx_sales_product` - Product queries
- `idx_sales_sold_at` - Date sorting
- `idx_sales_machine_date` - Composite index for machine+date queries

---

## 🔗 Foreign Key Updates

The migration also adds proper foreign key constraints to existing tables:

### Existing Tables Updated:
1. **`delivery_route_items`** → `products.id`
2. **`machine_refill_records`** → `products.id`, `vending_machines.id`, `slots.id`
3. **`inventory_transactions`** → `products.id`
4. **`warehouse_stock`** → `products.id` (already added in previous migration)
5. **`purchase_order_items`** → `products.id` (already added in previous migration)

---

## 📈 New Helper Views (4)

### 1. **`machine_inventory_status`**
Current inventory status for all vending machines.

**Columns:**
- `machine_id`, `machine_code`, `location`, `machine_status`
- `total_slots`, `slots_filled`, `total_items`, `total_capacity`
- `fill_percentage` - Capacity utilization

### 2. **`low_stock_slots`**
Slots with 3 or fewer items remaining.

**Columns:**
- `slot_id`, `slot_number`, `quantity`, `max_capacity`
- `machine_id`, `machine_code`, `location`
- `product_id`, `product_name`, `product_category`

### 3. **`sales_by_machine`**
Sales summary aggregated by vending machine.

**Columns:**
- `machine_id`, `machine_code`, `location`
- `total_sales`, `total_items_sold`, `total_revenue`
- `first_sale`, `last_sale`

### 4. **`popular_products_by_machine`**
Best-selling products per vending machine.

**Columns:**
- `machine_id`, `machine_code`, `location`
- `product_id`, `product_name`, `product_category`
- `times_sold`, `total_quantity_sold`, `total_revenue`

---

## 🗂️ Storage Bucket

### **`product-images`** Bucket
- **Public:** Yes
- **File Size Limit:** 5MB
- **Allowed Types:** JPEG, JPG, PNG, WebP, GIF

**Policies:**
- ✅ Authenticated users can upload
- ✅ Anyone can view (public)
- ✅ Authenticated users can update/delete

---

## 🔒 Security (RLS)

All new tables have:
- ✅ Row Level Security ENABLED
- ✅ Read access for authenticated users
- ✅ Full access for service role

---

## 📝 Permissions

Added 3 new pages to permissions system:
1. **`machines`** - Vending Machines
2. **`products`** - Products
3. **`sales`** - Sales

Admin role automatically gets full CRUD access.

---

## 🚀 Migration Files

### New Migration Created:
**[20251208125014_sync_prod_dev_schemas.sql](supabase/migrations/20251208125014_sync_prod_dev_schemas.sql)**

### Updated Migration:
**[20251208114450_new-migration.sql](supabase/migrations/20251208114450_new-migration.sql)** - Production optimization (from earlier)

---

## 📋 Complete Migration List

| # | Version | Description | Status |
|---|---------|-------------|--------|
| 1 | 20250101000000 | Initial schema | ✅ Applied |
| 2 | 20250102000000 | Role page permissions | ✅ Applied |
| 3 | 20250103000000 | User profiles | ✅ Applied |
| 4 | 20250117000000 | Warehouse management | ✅ Applied (Fixed) |
| 5 | 20250119000000 | Inventory integration | ✅ Applied (Fixed) |
| 6 | 20250122000000 | Product nutrition fields | ✅ Applied |
| 7 | 20250123000000 | Purchase order items FK | ✅ Applied (Fixed) |
| 8 | 20251122000000 | Remove machine group | ✅ Applied |
| 9 | 20251127000000 | Add supplier country code | ✅ Applied |
| 10 | 20251208114450 | Production optimization | 🆕 Ready |
| 11 | 20251208125014 | **Sync prod/dev schemas** | 🆕 **Ready** |

---

## 🎯 What This Migration Does

### Creates:
- ✅ 5 New tables (products, vending_machines, slots, machine_products, sales)
- ✅ 17 New indexes for performance
- ✅ 4 Helper views for common queries
- ✅ 1 Storage bucket with policies
- ✅ 10 RLS policies (2 per table)
- ✅ Foreign key constraints to link systems
- ✅ 3 New permission pages

### Updates:
- ✅ Links existing warehouse system to products
- ✅ Links machine refill records to machines/slots
- ✅ Links inventory transactions to products
- ✅ Adds proper referential integrity

---

## 📊 Database Architecture

```
┌──────────────┐
│   products   │◄──┐
└──────────────┘   │
       ▲           │
       │           │
       │      ┌────┴────────────┐       ┌─────────────────┐
       │      │ machine_products│◄──────┤ vending_machines│
       │      └─────────────────┘       └─────────────────┘
       │                                         ▲
       │                                         │
       │      ┌────────────┐                    │
       └──────┤   slots    │────────────────────┘
              └────────────┘
                    ▲
                    │
              ┌─────┴─────┐
              │   sales   │
              └───────────┘

┌──────────────────┐      ┌──────────────────┐
│    warehouses    │      │    suppliers     │
└──────────────────┘      └──────────────────┘
         │                         │
         │                         │
         ▼                         ▼
┌──────────────────┐      ┌──────────────────┐
│ warehouse_stock  │      │ purchase_orders  │
└──────────────────┘      └──────────────────┘
         │                         │
         │                         │
         └────────┬────────────────┘
                  ▼
         ┌──────────────────┐
         │ delivery_routes  │
         └──────────────────┘
                  │
                  ▼
         ┌──────────────────┐
         │machine_refill_rec│
         └──────────────────┘
```

---

## 🚀 Deployment Instructions

### Step 1: Review the Migration
```bash
cat supabase/migrations/20251208125014_sync_prod_dev_schemas.sql
```

### Step 2: Push to BOTH Environments

**For Development:**
```bash
cd /Users/misbahak/Desktop/mak/kwt/gcp/Cloud_backend/cloud_backend
supabase db push
```

**For Production:**
```bash
# Make sure you're linked to production
supabase link --project-ref your-prod-project-ref
supabase db push
```

### Step 3: Verify
```sql
-- Check all tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Check views exist
SELECT table_name FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- Test a view
SELECT * FROM public.machine_inventory_status LIMIT 5;
```

### Step 4: Update TypeScript Types (if needed)
```bash
# From your frontend directory
npx supabase gen types typescript --project-id your-project-ref > src/integrations/supabase/types.ts
```

---

## ✅ Post-Deployment Checklist

After pushing migrations:

- [ ] All tables created successfully
- [ ] All views working correctly
- [ ] Storage bucket accessible
- [ ] RLS policies active
- [ ] Foreign keys enforcing referential integrity
- [ ] Indexes improving query performance
- [ ] Permissions synced
- [ ] TypeScript types updated (if changed)
- [ ] Test vending machine operations
- [ ] Test product catalog
- [ ] Test sales tracking
- [ ] Test warehouse integration

---

## 📚 Usage Examples

### Check Machine Inventory
```sql
SELECT * FROM public.machine_inventory_status
WHERE fill_percentage < 50
ORDER BY fill_percentage ASC;
```

### Find Low Stock Slots
```sql
SELECT * FROM public.low_stock_slots
ORDER BY quantity ASC;
```

### Sales Report
```sql
SELECT * FROM public.sales_by_machine
WHERE total_revenue > 100
ORDER BY total_revenue DESC;
```

### Popular Products
```sql
SELECT * FROM public.popular_products_by_machine
ORDER BY total_quantity_sold DESC
LIMIT 10;
```

---

## 🆘 Troubleshooting

### If Foreign Key Errors Occur
This means data exists that doesn't match. Check:
```sql
-- Find orphaned records
SELECT * FROM public.delivery_route_items
WHERE product_id NOT IN (SELECT id FROM public.products);
```

### If Storage Bucket Already Exists
The migration handles this with `ON CONFLICT`, so it's safe.

### If Policies Fail
The migration includes `DROP POLICY IF EXISTS`, so it's idempotent.

---

## 🎊 Summary

✅ **11 Migrations Total**
✅ **5 New Tables** (products, vending_machines, slots, machine_products, sales)
✅ **8 Helper Views** (4 new + 4 from previous)
✅ **6 Helper Functions** (from previous)
✅ **30+ Indexes** for performance
✅ **Complete RLS Security**
✅ **Full Referential Integrity**
✅ **Production Ready**

**Both Production and Development databases will now have identical schemas!** 🚀
