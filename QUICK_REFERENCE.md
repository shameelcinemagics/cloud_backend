# 🚀 Quick Reference - VendCloud Migrations

## One-Line Deploy
```bash
supabase db push
```

---

## 📦 What You Have

| Item | Details |
|------|---------|
| **Main Migration** | 20251208000000_complete_database_schema.sql |
| **Tables** | 27 (auth + vending + warehouse) |
| **Policies** | 49 RLS policies |
| **Size** | 44KB (904 lines) |
| **Old Migrations** | Backed up in supabase/migrations_backup/ |

---

## 🛠️ Common Commands

### Deploy Migration
```bash
supabase db push
```

### Generate New Migration
```bash
npm run migrate:generate
```

### Check Migration Status
```bash
npm run migrate
```

### Create Custom Migration
```bash
supabase migration new my_feature
```

---

## 📊 Database Tables (27)

### Auth (7)
- schema_migrations, roles, pages, user_roles
- role_page_perms, user_page_perms, profiles, audit_logs

### Vending (7)
- products, vending_machines, slots, sales
- media, machine_media, transactions

### Warehouse (12)
- suppliers, warehouses, warehouse_stock
- purchase_orders, purchase_order_items
- delivery_routes, delivery_route_items
- stock_adjustments, ordering_triggers
- goods_receipt_notes, machine_refill_records
- inventory_transactions

---

## ✅ Quick Verification

```sql
-- Count tables (expect 27)
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public';

-- Count policies (expect 49+)
SELECT COUNT(*) FROM pg_policies
WHERE schemaname = 'public';

-- Check migration applied
SELECT * FROM public.schema_migrations
WHERE version = '20251208000000';
```

---

## 📚 Documentation

- MIGRATION_COMPLETE.md - Full summary
- FINAL_DEPLOYMENT_GUIDE.md - Deployment guide
- scripts/README.md - Script usage

---

## 🎯 Key Features

✅ **100% Idempotent** - Safe to run multiple times
✅ **Production Match** - Based on vend_it_base_schema.sql
✅ **Complete Security** - RLS policies on all tables
✅ **Optimized** - 50+ performance indexes
✅ **Automated** - Migration generator script included

---

## 🆘 Quick Help

**Tables already exist?** → No problem, uses IF NOT EXISTS
**Policies already exist?** → No problem, drops first with IF EXISTS
**Need old migrations?** → Check supabase/migrations_backup/
**Want fresh snapshot?** → Run npm run migrate:generate

---

**Ready to deploy?** Just run:
```bash
supabase db push
```
