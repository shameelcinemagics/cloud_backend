# VendCloud Backend - Migration Guide

This guide explains how to manage database migrations for the VendCloud backend system.

## Table of Contents
- [Overview](#overview)
- [Migration System](#migration-system)
- [Quick Start](#quick-start)
- [Applying Migrations](#applying-migrations)
- [Creating New Migrations](#creating-new-migrations)
- [Migration Best Practices](#migration-best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The VendCloud backend uses **Supabase** (PostgreSQL) for data persistence. We maintain versioned SQL migration files to track schema changes and ensure consistency across environments.

### Key Features
- ✅ **Conflict handling** - Uses `IF NOT EXISTS` and `ON CONFLICT` to prevent errors
- ✅ **Migration tracking** - Records applied migrations in `schema_migrations` table
- ✅ **Idempotent** - Safe to run migrations multiple times
- ✅ **Timestamped** - Migrations use YYYYMMDDHHMMSS format for ordering
- ✅ **Rollback support** - Includes rollback instructions as comments

## Migration System

### Directory Structure
```
VendCloud_backend/
├── supabase/
│   └── migrations/
│       ├── 20250101000000_initial_schema.sql
│       ├── README.md
│       └── [future migrations...]
├── migrations/           # Legacy location (deprecated)
│   └── 001_core.sql     # Original migration
└── scripts/
    └── runMigrations.ts # Migration runner script
```

### Migration Tracking Table

All migrations are tracked in the `schema_migrations` table:

```sql
CREATE TABLE public.schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT
);
```

**Check applied migrations:**
```sql
SELECT * FROM public.schema_migrations ORDER BY version;
```

## Quick Start

### Initial Setup

1. **Apply the initial schema migration** to Supabase:
   - Go to Supabase Dashboard → **SQL Editor**
   - Copy contents of `supabase/migrations/20250101000000_initial_schema.sql`
   - Paste and click **Run**

2. **Verify migration was applied:**
   ```sql
   SELECT * FROM public.schema_migrations;
   ```

3. **Create your first admin user:**
   ```bash
   # Option 1: Create user manually in Supabase Dashboard, then:
   npm run assign:admin

   # Option 2: If Supabase allows (may fail with "not_admin"):
   npm run seed:admin
   ```

## Applying Migrations

### Method 1: Supabase Dashboard (Recommended for Development)

**Pros:** Simple, visual, immediate feedback
**Cons:** Manual process, no automation

**Steps:**
1. Open Supabase Dashboard
2. Navigate to **SQL Editor**
3. Open migration file from `supabase/migrations/`
4. Copy entire SQL content
5. Paste into SQL Editor
6. Click **Run**
7. Verify in **Table Editor** that changes were applied

### Method 2: Supabase CLI (Recommended for Production)

**Pros:** Automated, version controlled, CI/CD friendly
**Cons:** Requires CLI installation

**Steps:**

1. **Install Supabase CLI:**
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase:**
   ```bash
   supabase login
   ```

3. **Link your project:**
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

   *Find your project ref in Supabase Dashboard → Settings → General*

4. **Apply all pending migrations:**
   ```bash
   supabase db push
   ```

5. **Verify migrations:**
   ```bash
   supabase db remote status
   ```

### Method 3: Direct psql Connection

**Pros:** Full PostgreSQL control
**Cons:** Requires connection string, more complex

**Steps:**

1. **Get connection string from Supabase:**
   - Dashboard → Settings → Database → Connection string (Direct)

2. **Run migration:**
   ```bash
   psql "postgresql://postgres:[PASSWORD]@[HOST]:[PORT]/postgres" \
     -f supabase/migrations/20250101000000_initial_schema.sql
   ```

### Method 4: Node.js Script (Limited)

**Note:** This script has limited functionality due to Supabase API restrictions.

```bash
npm run migrate
```

This will:
- ❌ Not execute SQL directly
- ✅ Check for pending migrations
- ✅ Display which migrations need to be applied
- ✅ Provide instructions for manual application

## Creating New Migrations

### Step 1: Create Migration File

**Generate timestamped filename:**

```bash
# Unix/Mac:
touch supabase/migrations/$(date +%Y%m%d%H%M%S)_your_description.sql

# Windows PowerShell:
New-Item -Path "supabase/migrations/$(Get-Date -Format 'yyyyMMddHHmmss')_your_description.sql"

# Manual:
# Create: 20250115123045_add_company_table.sql
```

### Step 2: Write Migration SQL

**Use this template:**

```sql
-- Migration: Add Company Table
-- Created: 2025-01-15
-- Description: Creates companies table with user associations

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250115123045', 'Add company table')
ON CONFLICT (version) DO NOTHING;

-- ===== Create Table =====
CREATE TABLE IF NOT EXISTS public.companies (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===== Indexes =====
CREATE INDEX IF NOT EXISTS idx_companies_slug ON public.companies(slug);
CREATE INDEX IF NOT EXISTS idx_companies_owner_id ON public.companies(owner_id);

-- ===== Enable RLS =====
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- ===== RLS Policies =====
DROP POLICY IF EXISTS "Users can read their own companies" ON public.companies;
CREATE POLICY "Users can read their own companies"
  ON public.companies FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can manage their own companies" ON public.companies;
CREATE POLICY "Users can manage their own companies"
  ON public.companies FOR ALL
  TO authenticated
  USING (owner_id = auth.uid());

-- ===== Triggers =====
DROP TRIGGER IF EXISTS update_companies_updated_at ON public.companies;
CREATE TRIGGER update_companies_updated_at
  BEFORE UPDATE ON public.companies
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ===== Comments =====
COMMENT ON TABLE public.companies IS 'Organizations that users belong to';

-- ===== Rollback Instructions =====
-- To rollback this migration:
-- DROP TABLE IF EXISTS public.companies CASCADE;
-- DELETE FROM public.schema_migrations WHERE version = '20250115123045';
```

### Step 3: Test Migration

1. **Test in development first:**
   - Apply to local Supabase or dev environment
   - Verify tables/columns created correctly
   - Test RLS policies work as expected

2. **Check for conflicts:**
   ```sql
   -- Check if table exists
   SELECT EXISTS (
     SELECT FROM pg_tables
     WHERE schemaname = 'public'
     AND tablename = 'companies'
   );
   ```

3. **Test rollback:**
   - Run rollback SQL
   - Verify clean removal
   - Re-apply migration to confirm idempotency

### Step 4: Apply to Production

1. **Backup database first** (Supabase handles this automatically)
2. Apply migration using preferred method
3. Verify in production environment
4. Monitor application logs for issues

## Migration Best Practices

### ✅ DO:

1. **Use idempotent operations:**
   ```sql
   CREATE TABLE IF NOT EXISTS ...
   CREATE INDEX IF NOT EXISTS ...
   DROP POLICY IF EXISTS ...
   INSERT ... ON CONFLICT DO NOTHING
   ```

2. **Add proper indexes:**
   ```sql
   -- Foreign keys
   CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);

   -- Frequently queried columns
   CREATE INDEX IF NOT EXISTS idx_pages_slug ON public.pages(slug);
   ```

3. **Enable RLS on all tables:**
   ```sql
   ALTER TABLE public.your_table ENABLE ROW LEVEL SECURITY;
   ```

4. **Add timestamps:**
   ```sql
   created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
   updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
   ```

5. **Include rollback instructions:**
   ```sql
   -- Rollback:
   -- DROP TABLE IF EXISTS ...
   ```

6. **Add comments for documentation:**
   ```sql
   COMMENT ON TABLE public.roles IS 'User roles (e.g., admin, manager)';
   COMMENT ON COLUMN public.user_page_perms.perms_mask IS 'Bitmask: C:1, R:2, U:4, D:8';
   ```

7. **Test migrations locally first**

8. **Keep migrations small and focused** - One migration = one logical change

### ❌ DON'T:

1. **Don't modify existing migrations** after they're applied to production
2. **Don't drop tables** without careful consideration and backups
3. **Don't forget foreign key constraints** and their ON DELETE behavior
4. **Don't skip migration tracking:**
   ```sql
   -- Always include:
   INSERT INTO public.schema_migrations (version, description)
   VALUES ('YYYYMMDDHHMMSS', 'Description')
   ON CONFLICT (version) DO NOTHING;
   ```
5. **Don't create migrations without conflict handling**
6. **Don't use reserved keywords** as column/table names
7. **Don't forget to grant permissions** if needed

## Error Handling in Code

### Using the Enhanced Error System

The codebase now includes a comprehensive error handling system:

```typescript
import {
  handleSupabaseError,
  validationError,
  notFoundError,
  alreadyExistsError,
  AppError
} from '../utils/errors.js';

// Example: Handle Supabase errors
try {
  const { data, error } = await supabaseAdmin
    .from('roles')
    .insert({ slug, label });

  if (error) {
    throw handleSupabaseError(error);
  }

  return data;
} catch (err) {
  if (err instanceof AppError) {
    // Error is already formatted
    throw err;
  }
  // Handle unexpected errors
  console.error('Unexpected error:', err);
  throw new AppError(ErrorCodes.INTERNAL_SERVER_ERROR, 'Operation failed');
}

// Example: Validation errors
if (!isValidUUID(user_id)) {
  throw validationError('user_id', 'Invalid UUID format');
}

// Example: Not found errors
if (!existingRole) {
  throw notFoundError('Role');
}

// Example: Already exists errors
if (duplicateCheck) {
  throw alreadyExistsError(`Role with slug "${slug}"`);
}
```

### Error Codes

All errors include standardized error codes:

```typescript
{
  "error": "A record with this value already exists",
  "code": "RES_4002",
  "details": { "originalError": "..." }
}
```

**Error code categories:**
- `AUTH_1xxx` - Authentication errors
- `AUTHZ_2xxx` - Authorization errors
- `VAL_3xxx` - Validation errors
- `RES_4xxx` - Resource errors
- `DB_5xxx` - Database errors
- `SYS_9xxx` - System errors

## Troubleshooting

### Issue: "relation already exists"

**Cause:** Migration was partially applied or table already exists

**Solution:**
```sql
-- Check if table exists
SELECT EXISTS (
  SELECT FROM pg_tables
  WHERE schemaname = 'public'
  AND tablename = 'your_table'
);

-- If exists, migration was already applied
-- Check migration tracking:
SELECT * FROM public.schema_migrations WHERE version = 'YYYYMMDDHHMMSS';
```

### Issue: "permission denied for table"

**Cause:** RLS policy blocking access

**Solution:**
```sql
-- Check RLS status
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

-- Check policies
SELECT * FROM pg_policies WHERE schemaname = 'public';

-- Temporarily disable RLS (NOT for production):
ALTER TABLE public.your_table DISABLE ROW LEVEL SECURITY;
```

### Issue: "foreign key violation"

**Cause:** Referenced record doesn't exist or wrong ON DELETE

**Solution:**
```sql
-- Check foreign key constraints
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'your_table';
```

### Issue: Migration tracking table doesn't exist

**Cause:** Initial migration not applied yet

**Solution:**
```sql
-- Create tracking table manually
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT
);
```

### Issue: Unique constraint violation on slug

**Cause:** Trying to insert duplicate slug value

**Solution:** This is handled automatically with `ON CONFLICT DO NOTHING`:
```sql
INSERT INTO public.roles (slug, label)
VALUES ('admin', 'Admin')
ON CONFLICT (slug) DO NOTHING;
```

## Support & Resources

- **Supabase Documentation:** https://supabase.com/docs
- **PostgreSQL Documentation:** https://www.postgresql.org/docs/
- **Migration Issues:** Check `schema_migrations` table
- **RLS Issues:** Check `pg_policies` system catalog

## Next Steps

1. ✅ Apply initial migration (`20250101000000_initial_schema.sql`)
2. ✅ Verify migration tracking is working
3. ✅ Create your first admin user
4. ✅ Test all API endpoints
5. 📝 Create new migrations as needed

---

**Last Updated:** 2025-01-01
**Version:** 1.0.0
