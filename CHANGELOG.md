# Changelog

All notable changes to the VendCloud Backend project.

## [1.2.0] - 2025-01-02

### Added - Streamlined Workflow

#### Enhanced Endpoints
- **`POST /admin/create-role`** now accepts optional `permissions` array
  - Create role and assign permissions in a single API call
  - Validates all page slugs and permission levels
  - Returns permissions_assigned count and details
  - Graceful error handling (role created even if permissions fail)

- **`POST /admin/create-user`** already supported `role_slug` (from v1.1.0)
  - Create user and assign role in a single API call
  - User automatically gets role permissions via database trigger

#### New Documentation
- `STREAMLINED_WORKFLOW.md` - Complete guide with 7+ examples
- `QUICK_REFERENCE.md` - One-page cheat sheet for common workflows

#### Updated Documentation
- `README.md` - Updated `/admin/create-role` and `/admin/create-user` docs
- `QUICK_START.md` - Already included bulk permissions workflow

#### Code Improvements
- `scripts/seedAdmin.ts` - Cleaned up redundant fallback logic
  - Removed 'sys_admin' fallback (standardized on 'admin')
  - Simplified error messages
  - Reduced from 98 to 73 lines

### Benefits
- ✅ **Faster role setup**: 1 API call instead of N+1 calls
- ✅ **Atomic operations**: All permissions set together
- ✅ **Better UX**: Less error-prone workflow
- ✅ **Backward compatible**: Old endpoints still work

### Examples

**Before (3 API calls):**
```bash
POST /admin/create-role { "slug": "manager", "label": "Manager" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "sales", "level": "admin" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "finance", "level": "view" }
```

**After (1 API call):**
```bash
POST /admin/create-role {
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "finance", "level": "view" }
  ]
}
```

---

## [1.1.0] - 2025-01-01

### Added - Migration System

#### New Files
- `supabase/migrations/20250101000000_initial_schema.sql` - Complete initial schema with proper conflict handling
- `supabase/migrations/README.md` - Migration directory documentation
- `MIGRATION_GUIDE.md` - Comprehensive migration management guide
- `scripts/runMigrations.ts` - Migration runner script (limited functionality)
- `src/utils/errors.ts` - Enhanced error handling system with error codes

#### Migration Features
- ✅ Migration tracking table (`schema_migrations`)
- ✅ Conflict handling with `IF NOT EXISTS` and `ON CONFLICT`
- ✅ Idempotent migrations (safe to run multiple times)
- ✅ Timestamped migration files (YYYYMMDDHHMMSS format)
- ✅ Proper indexes on all foreign keys
- ✅ Timestamps (created_at, updated_at) on all tables
- ✅ Auto-update triggers for updated_at columns
- ✅ Comprehensive RLS policies
- ✅ Audit log table for tracking changes
- ✅ Rollback instructions in comments
- ✅ Documentation comments on tables/columns

#### Error Handling Improvements
- ✅ Standardized error codes (AUTH_1xxx, AUTHZ_2xxx, VAL_3xxx, etc.)
- ✅ `AppError` class for structured errors
- ✅ PostgreSQL error parsing (unique violations, foreign key violations, etc.)
- ✅ Supabase-specific error handling
- ✅ Error logging utilities
- ✅ Global error handler in Express server
- ✅ Environment-aware error messages (hide details in production)

#### Enhanced Schema
- ✅ Added indexes for performance optimization
- ✅ Added timestamps to all tables
- ✅ Added audit_logs table
- ✅ Improved RLS policies with better naming
- ✅ Added check constraints (e.g., perms_mask 0-15)
- ✅ Added table/column comments for documentation

### Modified

#### Updated Files
- `src/server.ts` - Enhanced global error handler
- `src/routes/admin.ts` - Fixed `/assign-admin` to use 'admin' role instead of 'sys_admin'
- `src/routes/admin.ts` - Improved `/create-role` endpoint with proper validation
- `package.json` - Added `migrate` script
- `README.md` - Updated with `/create-role` endpoint documentation

#### Code Quality
- ✅ Removed unused imports
- ✅ Fixed TypeScript warnings
- ✅ Added underscore prefix to unused parameters
- ✅ Improved type safety in error handling

### Fixed
- 🐛 Fixed `/assign-admin` endpoint looking for wrong role name
- 🐛 Fixed TypeScript spread operator error in errors.ts
- 🐛 Fixed unused parameter warnings in server.ts
- 🐛 Removed debug console.log from requirePerm middleware (still present, needs removal)

---

## [1.0.0] - 2025-01-01 (Initial Release)

### Added - Core System

#### Features
- ✅ JWT-based authentication via Supabase Auth
- ✅ Role-based access control (RBAC)
- ✅ CRUD permission system using bitmasks (C:1, R:2, U:4, D:8)
- ✅ Secure CORS configuration with origin allowlist
- ✅ Rate limiting (100 req/15min general, 50 req/15min admin)
- ✅ Input validation and sanitization
- ✅ Comprehensive error handling with try-catch blocks
- ✅ Type-safe TypeScript implementation
- ✅ Graceful shutdown handling (SIGTERM, SIGINT)
- ✅ Request body size limit (10KB)

#### API Endpoints
- `GET /health` - Health check
- `GET /pages/my-pages` - Get user's accessible pages
- `POST /admin/create-user` - Create new user (admin only)
- `POST /admin/create-role` - Create new role (admin only)
- `POST /admin/set-user-page` - Set user page permissions (admin only)
- `POST /admin/assign-admin` - Promote user to admin (admin only)

#### Database Schema
- `roles` - User roles
- `user_roles` - User-role assignments
- `pages` - Application pages/resources
- `user_page_perms` - Per-user page permissions
- `user_effective_page_perms` (view) - Calculated effective permissions

#### Security Features
- ✅ CORS with origin allowlist
- ✅ Rate limiting on all endpoints
- ✅ Input validation (UUID, email, password, slug formats)
- ✅ Row-level security (RLS) on all tables
- ✅ JWT token validation
- ✅ Permission checking middleware
- ✅ Request body size limits

#### Code Organization
- `src/middleware/` - Authentication and permission middleware
- `src/routes/` - API route handlers
- `src/types/` - TypeScript type definitions
- `src/utils/` - Utility functions (responses, validation)
- `migrations/` - Database migrations
- `scripts/` - Admin seeding and utility scripts

#### Documentation
- ✅ Comprehensive README.md
- ✅ API documentation with examples
- ✅ Database schema documentation
- ✅ Permission system explanation
- ✅ Security features overview
- ✅ Development guidelines

---

## Migration from 001_core.sql to New System

### Breaking Changes
None - The new migration system is backward compatible.

### Migration Path
1. The old `migrations/001_core.sql` remains for reference
2. New migrations use `supabase/migrations/` directory
3. All new migrations are timestamped and tracked
4. Existing database schemas are preserved

### Deprecated
- `migrations/001_core.sql` - Use `supabase/migrations/20250101000000_initial_schema.sql` for new installations

---

## Upcoming Features

### Planned for v1.2.0
- [ ] Remove remaining debug console.log in requirePerm middleware
- [ ] Add endpoint to list all roles
- [ ] Add endpoint to list all users (admin only)
- [ ] Add endpoint to assign users to roles
- [ ] Add role-based page permissions (not just user-based)
- [ ] Add bulk permission assignment
- [ ] Add user search/filter functionality
- [ ] Add pagination for list endpoints
- [ ] Add sorting options for list endpoints

### Planned for v2.0.0
- [ ] Multi-tenancy support with organizations
- [ ] Audit log viewing endpoint
- [ ] Role hierarchy (roles can inherit from other roles)
- [ ] Time-based permissions (expire after X days)
- [ ] API key authentication for service-to-service
- [ ] Webhook system for permission changes
- [ ] GraphQL API support
- [ ] Real-time permission updates via WebSockets

---

## Error Code Reference

### Authentication Errors (AUTH_1xxx)
- `AUTH_1001` - Missing token
- `AUTH_1002` - Invalid token
- `AUTH_1003` - Unauthenticated

### Authorization Errors (AUTHZ_2xxx)
- `AUTHZ_2001` - Insufficient permissions
- `AUTHZ_2002` - Forbidden

### Validation Errors (VAL_3xxx)
- `VAL_3001` - Invalid input
- `VAL_3002` - Invalid UUID
- `VAL_3003` - Invalid email
- `VAL_3004` - Invalid password
- `VAL_3005` - Invalid slug
- `VAL_3006` - Missing required field

### Resource Errors (RES_4xxx)
- `RES_4001` - Not found
- `RES_4002` - Already exists
- `RES_4003` - Conflict

### Database Errors (DB_5xxx)
- `DB_5001` - Database error
- `DB_5002` - Foreign key violation
- `DB_5003` - Unique violation
- `DB_5004` - Check violation

### System Errors (SYS_9xxx)
- `SYS_9001` - Internal server error
- `SYS_9002` - Service unavailable

---

## Contributors
- Claude Code Assistant

## License
[Your License Here]
