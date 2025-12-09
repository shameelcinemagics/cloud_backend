# Database Migrations

This directory contains Supabase database migrations for the VendCloud backend.

## Migration Naming Convention

Migrations follow this naming pattern:
```
YYYYMMDDHHMMSS_description.sql
```

Example: `20250101000000_initial_schema.sql`

## Current Migrations

| Version | Description | Status |
|---------|-------------|--------|
| 20250101000000 | Initial schema - roles, pages, permissions | Applied |

## How to Apply Migrations

### Option 1: Supabase CLI (Recommended)

1. Install Supabase CLI:
```bash
npm install -g supabase
```

2. Link your project:
```bash
supabase link --project-ref your-project-ref
```

3. Apply all pending migrations:
```bash
supabase db push
```

### Option 2: Supabase Dashboard

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the migration SQL
4. Click **Run**

### Option 3: Migration Script (Node.js)

Run the migration script:
```bash
npm run migrate
```

## Creating New Migrations

1. Create a new file with timestamp:
```bash
# On Unix/Mac:
touch supabase/migrations/$(date +%Y%m%d%H%M%S)_your_description.sql

# On Windows PowerShell:
New-Item -Path "supabase/migrations/$(Get-Date -Format 'yyyyMMddHHmmss')_your_description.sql"
```

2. Add your SQL with this template:

```sql
-- Migration: Your Description
-- Created: YYYY-MM-DD
-- Description: What this migration does

-- Record this migration
insert into public.schema_migrations (version, description)
values ('YYYYMMDDHHMMSS', 'Your description')
on conflict (version) do nothing;

-- Your migration SQL here
-- ...

-- Rollback instructions (as comments):
-- DROP TABLE IF EXISTS ...
```

## Migration Best Practices

### ✅ DO:
- Use `create table if not exists` for idempotency
- Use `on conflict do nothing` for insert statements
- Add indexes for foreign keys and frequently queried columns
- Use `drop policy if exists` before creating policies
- Include rollback instructions as comments
- Add timestamps (created_at, updated_at) to tables
- Enable RLS on all tables
- Add descriptive comments to tables and columns

### ❌ DON'T:
- Don't drop tables in migrations (use separate rollback script)
- Don't modify existing migrations after they're applied
- Don't forget to track migrations in schema_migrations table
- Don't create migrations without proper conflict handling

## Schema Organization

```
public.roles                    # User roles
public.user_roles              # User-role assignments
public.pages                   # Application pages/resources
public.user_page_perms         # Direct user permissions
public.user_effective_page_perms (view) # Calculated permissions
public.audit_logs              # Audit trail
public.schema_migrations       # Migration tracking
```

## Checking Migration Status

Query the migrations table:
```sql
SELECT * FROM public.schema_migrations ORDER BY version;
```

## Rollback Strategy

For rollback, create a separate down migration:
```sql
-- migrations/20250101000000_initial_schema_down.sql
-- Rollback for: Initial schema

-- Remove migration record
DELETE FROM public.schema_migrations WHERE version = '20250101000000';

-- Drop objects in reverse order
DROP VIEW IF EXISTS public.user_effective_page_perms;
DROP TABLE IF EXISTS public.user_page_perms;
DROP TABLE IF EXISTS public.user_roles;
DROP TABLE IF EXISTS public.pages;
DROP TABLE IF EXISTS public.roles;
DROP TABLE IF EXISTS public.audit_logs;
```

## Troubleshooting

### Migration Already Applied
If you see "already exists" errors, the migration was already applied. Check:
```sql
SELECT * FROM public.schema_migrations;
```

### Permission Errors
Ensure your database user has proper permissions:
```sql
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
```

### RLS Blocking Access
If queries fail due to RLS, verify policies:
```sql
SELECT * FROM pg_policies WHERE schemaname = 'public';
```

## Support

For migration issues, check:
1. Supabase Dashboard → Database → Migrations
2. Supabase Dashboard → SQL Editor → Query History
3. Application logs for migration errors
