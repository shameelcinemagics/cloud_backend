# Database Migration Scripts

## 📋 Overview

This directory contains scripts for managing database migrations and setup tasks.

---

## 🚀 Available Scripts

### 1. **Generate Migration** (NEW!)
Generates a complete safe migration file for all your database tables.

```bash
npm run migrate:generate
```

**What it does:**
- ✅ Generates migration file with all production tables
- ✅ Uses `CREATE TABLE IF NOT EXISTS` (safe to re-run)
- ✅ Includes all indexes
- ✅ Includes RLS policies
- ✅ Creates timestamped migration file in `supabase/migrations/`

**Generated tables (27 total):**

**Authentication & Authorization (7):**
1. schema_migrations
2. roles
3. pages
4. user_roles
5. role_page_perms
6. user_page_perms
7. profiles
8. audit_logs

**Vending Operations (7):**
9. products (with partNo)
10. vending_machines
11. slots (with custom_price)
12. sales
13. media
14. machine_media
15. transactions

**Warehouse & Inventory (12):**
16. suppliers
17. warehouses
18. warehouse_stock
19. purchase_orders
20. purchase_order_items
21. delivery_routes
22. delivery_route_items
23. stock_adjustments
24. ordering_triggers
25. goods_receipt_notes
26. machine_refill_records
27. inventory_transactions

**Output:**
```
✅ Migration file generated successfully!

📄 File: 20251208150000_complete_database_schema.sql
📍 Path: /path/to/supabase/migrations/20251208150000_complete_database_schema.sql

🔍 This migration includes:
   - All 27 tables (auth + vending + warehouse)
   - IF NOT EXISTS checks (safe to re-run)
   - All indexes and constraints
   - Complete RLS policies
```

---

### 2. **Run Migrations**
Checks and lists pending migrations.

```bash
npm run migrate
```

**What it does:**
- 📊 Connects to your Supabase database
- 📋 Lists applied and pending migrations
- ⚠️ Recommends using Supabase CLI for actual migration

**Note:** This script provides limited functionality. For full migration support:
1. **Recommended:** `supabase db push`
2. **Alternative:** Copy SQL to Supabase Dashboard
3. **Advanced:** Use direct `psql` connection

---

### 3. **Seed Admin**
Creates admin users in the database.

```bash
npm run seed:admin
```

---

### 4. **Assign Admin Role (SQL)**
Assigns admin role using SQL.

```bash
npm run assign:admin
```

---

## 🔧 Setup

### Prerequisites
1. Node.js installed
2. Environment variables configured in `.env`:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```

### Installation
```bash
npm install
```

---

## 📦 Migration Workflow

### Complete Workflow

#### Step 1: Generate Migration
```bash
npm run migrate:generate
```

This creates a new migration file in `supabase/migrations/` with all your tables.

#### Step 2: Review Migration
Open the generated file and review the SQL:
```bash
cat supabase/migrations/20251208150000_complete_schema_safe.sql
```

#### Step 3: Apply Migration
Choose one of these methods:

**Option A: Supabase CLI (Recommended)**
```bash
supabase db push
```

**Option B: Supabase Dashboard**
1. Copy the SQL from the generated file
2. Go to Supabase Dashboard → SQL Editor
3. Paste and run

**Option C: Direct psql**
```bash
psql "your-connection-string" -f supabase/migrations/20251208150000_complete_schema_safe.sql
```

#### Step 4: Verify
```bash
npm run migrate
```

This will show you which migrations have been applied.

---

## 🔍 Generated Migration Features

The `migrate:generate` script creates a migration with:

### Safety Features
- ✅ `CREATE TABLE IF NOT EXISTS` - Won't fail if table exists
- ✅ `CREATE INDEX IF NOT EXISTS` - Won't fail if index exists
- ✅ `DROP POLICY IF EXISTS` - Safe policy recreation
- ✅ `ON CONFLICT DO NOTHING` - Safe constraint handling

### What's Included
1. **All Tables** - Complete schema from production
2. **Indexes** - Performance optimized indexes
3. **Constraints** - Foreign keys, checks, unique constraints
4. **RLS Policies** - Row Level Security for all tables
5. **Migration Tracking** - Records in `schema_migrations` table

---

## 📊 Migration File Structure

```sql
-- Header with metadata
-- Migration tracking record

-- ============================================================================
-- TABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.vending_machines (...);
CREATE TABLE IF NOT EXISTS public.products (...);
-- ... more tables

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_vending_machines_machine_id ...;
CREATE INDEX IF NOT EXISTS idx_products_name ...;
-- ... more indexes

-- ============================================================================
-- RLS POLICIES
-- ============================================================================
ALTER TABLE public.vending_machines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "..." ON public.vending_machines;
CREATE POLICY "..." ON public.vending_machines ...;
-- ... more policies
```

---

## 🎯 Use Cases

### Use Case 1: Initial Database Setup
When setting up a new environment:
```bash
npm run migrate:generate  # Generate schema
supabase db push         # Apply to database
```

### Use Case 2: Schema Synchronization
When syncing dev with production:
```bash
npm run migrate:generate  # Generate current schema
# Review generated file
supabase db push         # Sync to target environment
```

### Use Case 3: Backup Schema as Code
Periodically generate migration files as backups:
```bash
npm run migrate:generate
git add supabase/migrations/*.sql
git commit -m "chore: update schema snapshot"
```

---

## ⚠️ Important Notes

### Safety
- ✅ Safe to run multiple times (idempotent)
- ✅ Won't drop or modify existing data
- ✅ Only creates missing objects

### Limitations
- ⚠️ Doesn't handle schema changes (ALTER TABLE)
- ⚠️ Doesn't drop objects
- ⚠️ Doesn't migrate data

### Best Practices
1. **Always review** generated SQL before applying
2. **Test in development** first
3. **Backup production** before applying
4. **Version control** all migration files
5. **Use descriptive** commit messages

---

## 🔄 Manual Migration Creation

If you need to create a custom migration:

```bash
# Create new migration file
supabase migration new my_custom_migration

# Edit the file
vim supabase/migrations/20251208150000_my_custom_migration.sql

# Apply migration
supabase db push
```

---

## 📚 Additional Resources

- [Supabase CLI Documentation](https://supabase.com/docs/guides/cli)
- [Database Migrations Guide](https://supabase.com/docs/guides/database/migrations)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

---

## 🆘 Troubleshooting

### "Migration file not created"
- Check write permissions on `supabase/migrations/` directory
- Ensure directory exists: `mkdir -p supabase/migrations`

### "Connection failed"
- Verify `.env` file has correct Supabase credentials
- Check `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`

### "Table already exists" errors
- ✅ This is normal! Script uses `IF NOT EXISTS`
- These are warnings, not errors
- Migration will skip existing tables

### "Cannot execute SQL"
- Some operations require Supabase CLI
- Use `supabase db push` instead
- Or copy SQL to Dashboard manually

---

## 🎉 Summary

The migration generator provides a **safe, automated way** to:
- ✅ Create complete database schema
- ✅ Synchronize environments
- ✅ Version control your schema
- ✅ Deploy with confidence

**Quick Start:**
```bash
npm run migrate:generate  # Generate
supabase db push         # Deploy
npm run migrate          # Verify
```

Happy migrating! 🚀
