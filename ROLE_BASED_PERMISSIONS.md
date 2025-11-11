# Role-Based Permissions System

Complete guide to the role-based permissions system in VendCloud Backend.

## Table of Contents
- [Overview](#overview)
- [How It Works](#how-it-works)
- [Setup](#setup)
- [API Endpoints](#api-endpoints)
- [Usage Examples](#usage-examples)
- [Permission Priority](#permission-priority)
- [Best Practices](#best-practices)

---

## Overview

The VendCloud backend uses a flexible **role-based access control (RBAC)** system that allows you to:

1. ✅ Create custom roles
2. ✅ Assign default page permissions to roles
3. ✅ Create users with roles automatically
4. ✅ Override role permissions with user-specific permissions
5. ✅ Grant automatic permissions when assigning roles

### Key Concepts

- **Role**: A named group (e.g., "admin", "manager", "viewer")
- **Page**: A resource/section in your app (e.g., "dashboard", "sales", "settings")
- **Permission Mask**: Bitmask for CRUD operations (C:1, R:2, U:4, D:8)
- **Role Permission**: Default permissions a role has on a page
- **User Permission**: User-specific override permissions

---

## How It Works

### Permission Hierarchy (Highest to Lowest)

1. **Admin Role** → Always gets full CRUD (15) on all pages
2. **User-Specific Permissions** → Overrides role permissions if set
3. **Role Permissions** → Default permissions from assigned role(s)
4. **No Permission** → No access (0)

### Database Tables

```
roles                  # Available roles (admin, manager, etc.)
├─ user_roles          # Users assigned to roles
└─ role_page_perms     # Default permissions for each role on each page

pages                  # Available pages/resources
├─ user_page_perms     # User-specific permission overrides
└─ role_page_perms     # Role-based default permissions

user_effective_page_perms (VIEW)  # Calculated final permissions
```

### Automatic Permission Grant

When you assign a role to a user, the system **automatically copies** that role's page permissions to the user (via database trigger). This means:
- User immediately gets access based on their role
- Permissions persist even if role permissions change later
- You can still override individual user permissions

---

## Setup

### Step 1: Apply Migration

Apply the role-based permissions migration:

**Option 1: Supabase Dashboard**
1. Go to SQL Editor
2. Copy contents of `supabase/migrations/20250102000000_role_page_permissions.sql`
3. Run the SQL

**Option 2: Supabase CLI**
```bash
supabase db push
```

### Step 2: Verify Tables Exist

```sql
-- Check tables
SELECT tablename FROM pg_tables WHERE schemaname = 'public';

-- Should include:
-- - role_page_perms (NEW)
-- - roles
-- - user_roles
-- - pages
-- - user_page_perms
```

### Step 3: Set Up Roles

Create roles for your organization:

```bash
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager"
}
```

```bash
POST /admin/create-role
{
  "slug": "viewer",
  "label": "Viewer"
}
```

### Step 4: Configure Role Permissions

Give roles default permissions on pages:

```bash
# Managers get full access to sales
POST /admin/set-role-page
{
  "role_slug": "manager",
  "page_slug": "sales",
  "level": "admin"  # Full CRUD
}

# Managers get read-only access to finance
POST /admin/set-role-page
{
  "role_slug": "manager",
  "page_slug": "finance",
  "level": "view"  # Read only
}

# Viewers get read-only access to dashboard
POST /admin/set-role-page
{
  "role_slug": "viewer",
  "page_slug": "dashboard",
  "level": "view"
}
```

---

## API Endpoints

### 1. Create User with Role

**Endpoint:** `POST /admin/create-user`

**Description:** Creates a user and optionally assigns a role. If role is assigned, user automatically gets that role's permissions.

**Request:**
```json
{
  "email": "john@example.com",
  "password": "securePass123",
  "email_confirm": true,
  "role_slug": "manager"  // Optional
}
```

**Response:**
```json
{
  "user": {
    "id": "uuid",
    "email": "john@example.com",
    "created_at": "2025-01-01T00:00:00Z"
  },
  "role_assigned": true,
  "role_slug": "manager"
}
```

**Permissions:** Requires UPDATE on "settings" page

---

### 2. Create Role

**Endpoint:** `POST /admin/create-role`

**Description:** Creates a new role.

**Request:**
```json
{
  "slug": "manager",
  "label": "Manager"
}
```

**Response:**
```json
{
  "role": {
    "id": 2,
    "slug": "manager",
    "label": "Manager"
  }
}
```

**Permissions:** Requires UPDATE on "settings" page

---

### 3. Set Role Page Permissions

**Endpoint:** `POST /admin/set-role-page`

**Description:** Sets default permissions for a role on a specific page. All users with this role will get these permissions (unless overridden).

**Request:**
```json
{
  "role_slug": "manager",
  "page_slug": "sales",
  "level": "admin"  // "view", "admin", or "none"
}
```

**Response:**
```json
{
  "ok": true,
  "level": "admin",
  "perms_mask": 15
}
```

**Levels:**
- `view`: Read-only (2)
- `admin`: Full CRUD (15)
- `none`: Remove permissions

**Permissions:** Requires UPDATE on "settings" page

---

### 4. Set User Page Permissions (Override)

**Endpoint:** `POST /admin/set-user-page`

**Description:** Sets user-specific permissions, overriding role defaults.

**Request:**
```json
{
  "user_id": "uuid",
  "page_slug": "finance",
  "level": "admin"
}
```

**Response:**
```json
{
  "ok": true,
  "level": "admin",
  "perms_mask": 15
}
```

**Permissions:** Requires UPDATE on "settings" page

---

### 5. Get All Roles

**Endpoint:** `GET /admin/roles`

**Description:** Lists all roles with their page permissions.

**Response:**
```json
{
  "roles": [
    {
      "id": 1,
      "slug": "admin",
      "label": "Admin",
      "permissions": [
        {
          "page_slug": "dashboard",
          "page_label": "Dashboard",
          "perms_mask": 15
        }
      ]
    },
    {
      "id": 2,
      "slug": "manager",
      "label": "Manager",
      "permissions": [
        {
          "page_slug": "sales",
          "page_label": "Sales",
          "perms_mask": 15
        },
        {
          "page_slug": "finance",
          "page_label": "Finance",
          "perms_mask": 2
        }
      ]
    }
  ]
}
```

**Permissions:** Requires READ on "settings" page

---

### 6. Get All Users

**Endpoint:** `GET /admin/users`

**Description:** Lists all users with their assigned roles.

**Response:**
```json
{
  "users": [
    {
      "id": "uuid",
      "email": "john@example.com",
      "created_at": "2025-01-01T00:00:00Z",
      "last_sign_in_at": "2025-01-01T10:00:00Z",
      "role": {
        "id": 2,
        "slug": "manager",
        "label": "Manager"
      }
    }
  ]
}
```

**Permissions:** Requires READ on "users" page

---

### 7. Assign Admin Role

**Endpoint:** `POST /admin/assign-admin`

**Description:** Promotes a user to admin (gets full access to everything).

**Request:**
```json
{
  "user_id": "uuid"
}
```

**Response:**
```json
{
  "ok": true
}
```

**Permissions:** Requires UPDATE on "settings" page

---

## Usage Examples

### Example 1: Create Manager Role with Permissions

```bash
# Step 1: Create the role
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager"
}

# Step 2: Give managers full access to sales
POST /admin/set-role-page
{
  "role_slug": "manager",
  "page_slug": "sales",
  "level": "admin"
}

# Step 3: Give managers read access to finance
POST /admin/set-role-page
{
  "role_slug": "manager",
  "page_slug": "finance",
  "level": "view"
}

# Step 4: Give managers full access to products
POST /admin/set-role-page
{
  "role_slug": "manager",
  "page_slug": "products",
  "level": "admin"
}

# Step 5: Create a user with manager role
POST /admin/create-user
{
  "email": "manager@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}

# ✅ User now automatically has:
# - Full CRUD on sales (15)
# - Read-only on finance (2)
# - Full CRUD on products (15)
# - No access to other pages (0)
```

---

### Example 2: Create Viewer Role (Read-Only)

```bash
# Step 1: Create viewer role
POST /admin/create-role
{
  "slug": "viewer",
  "label": "Viewer"
}

# Step 2: Give read-only access to multiple pages
POST /admin/set-role-page
{ "role_slug": "viewer", "page_slug": "dashboard", "level": "view" }

POST /admin/set-role-page
{ "role_slug": "viewer", "page_slug": "sales", "level": "view" }

POST /admin/set-role-page
{ "role_slug": "viewer", "page_slug": "products", "level": "view" }

# Step 3: Create viewer users
POST /admin/create-user
{
  "email": "viewer1@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "viewer"
}
```

---

### Example 3: Override User Permissions

```bash
# Scenario: A manager needs admin access to finance (normally read-only)

# Give specific user admin access to finance
POST /admin/set-user-page
{
  "user_id": "manager-uuid",
  "page_slug": "finance",
  "level": "admin"
}

# ✅ This user now has admin access to finance
# ✅ Other managers still have read-only
```

---

### Example 4: Multi-Level Organization

```bash
# Create roles
POST /admin/create-role { "slug": "ceo", "label": "CEO" }
POST /admin/create-role { "slug": "department_head", "label": "Department Head" }
POST /admin/create-role { "slug": "employee", "label": "Employee" }

# CEO gets almost everything (but not admin tools)
POST /admin/set-role-page { "role_slug": "ceo", "page_slug": "dashboard", "level": "admin" }
POST /admin/set-role-page { "role_slug": "ceo", "page_slug": "sales", "level": "admin" }
POST /admin/set-role-page { "role_slug": "ceo", "page_slug": "finance", "level": "admin" }
POST /admin/set-role-page { "role_slug": "ceo", "page_slug": "users", "level": "view" }

# Department heads get their department access
POST /admin/set-role-page { "role_slug": "department_head", "page_slug": "dashboard", "level": "view" }
POST /admin/set-role-page { "role_slug": "department_head", "page_slug": "sales", "level": "admin" }
POST /admin/set-role-page { "role_slug": "department_head", "page_slug": "products", "level": "admin" }

# Employees get limited access
POST /admin/set-role-page { "role_slug": "employee", "page_slug": "dashboard", "level": "view" }
POST /admin/set-role-page { "role_slug": "employee", "page_slug": "sales", "level": "view" }
```

---

## Permission Priority

### Scenario 1: User with Admin Role
```
✅ Admin role → Gets FULL CRUD (15) on ALL pages
❌ Role permissions → Ignored
❌ User permissions → Ignored
```

### Scenario 2: User with Custom Role + User Override
```
User: John (Manager role)
Manager role has: Sales = 15, Finance = 2
User override: Finance = 15

Result:
- Sales: 15 (from role)
- Finance: 15 (user override)
- Other pages: 0 (no access)
```

### Scenario 3: User with Custom Role (No Overrides)
```
User: Jane (Manager role)
Manager role has: Sales = 15, Finance = 2

Result:
- Sales: 15 (from role)
- Finance: 2 (from role)
- Other pages: 0 (no access)
```

### Scenario 4: User with No Role
```
User: Guest (no role)

Result:
- All pages: 0 (no access)
```

---

## Best Practices

### 1. Design Role Hierarchy First
```
admin          → Full system access
manager        → Department management
team_lead      → Team-level operations
employee       → Basic operations
viewer         → Read-only access
```

### 2. Use Roles for Groups, User Perms for Exceptions
```
✅ DO: Create "sales_manager" role with standard permissions
✅ DO: Override individual users when they need special access
❌ DON'T: Create a role for every permission combination
```

### 3. Document Your Roles
```sql
COMMENT ON TABLE public.roles IS 'User roles for access control';

-- Add role descriptions in your app
{
  "slug": "manager",
  "label": "Manager",
  "description": "Can manage sales, products, and view finance data"
}
```

### 4. Audit Role Changes
```typescript
// Log role assignments
console.log(`User ${userId} assigned role ${roleSlug} by admin ${adminId}`);

// Use the audit_logs table (from migration)
INSERT INTO audit_logs (user_id, table_name, action, new_data)
VALUES (admin_id, 'user_roles', 'INSERT', jsonb_build_object(...));
```

### 5. Test Permission Scenarios
```bash
# Test as different users
# 1. Create test users with different roles
# 2. Call /pages/my-pages to see their permissions
# 3. Verify they can only access allowed pages
```

---

## Troubleshooting

### User Not Getting Role Permissions

**Check:**
1. Role exists: `SELECT * FROM roles WHERE slug = 'role_slug';`
2. Role assigned: `SELECT * FROM user_roles WHERE user_id = 'uuid';`
3. Role has permissions: `SELECT * FROM role_page_perms WHERE role_id = X;`
4. Trigger exists: `SELECT * FROM pg_trigger WHERE tgname = 'trigger_grant_role_permissions';`

**Fix:**
```sql
-- Manually grant permissions
INSERT INTO user_page_perms (user_id, page_id, perms_mask)
SELECT 'user-uuid', page_id, perms_mask
FROM role_page_perms
WHERE role_id = (SELECT id FROM roles WHERE slug = 'role_slug')
ON CONFLICT (user_id, page_id) DO NOTHING;
```

### Role Permissions Not Working

**Check effective permissions view:**
```sql
SELECT * FROM user_effective_page_perms
WHERE user_id = 'uuid';
```

### User Has Wrong Permissions

**Priority order:**
1. Check if admin: `SELECT * FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = 'uuid' AND r.slug = 'admin';`
2. Check user overrides: `SELECT * FROM user_page_perms WHERE user_id = 'uuid';`
3. Check role perms: `SELECT * FROM role_page_perms WHERE role_id IN (SELECT role_id FROM user_roles WHERE user_id = 'uuid');`

---

## Summary

The role-based permissions system provides:
- ✅ **Flexible access control** - Roles + user overrides
- ✅ **Automatic permission grant** - Users immediately get role permissions
- ✅ **Easy to manage** - Set role permissions once, apply to many users
- ✅ **Secure by default** - No permissions unless explicitly granted
- ✅ **Scalable** - Supports complex organizational hierarchies

**Next Steps:**
1. Apply the migration: `supabase/migrations/20250102000000_role_page_permissions.sql`
2. Create your roles: `POST /admin/create-role`
3. Configure role permissions: `POST /admin/set-role-page`
4. Create users with roles: `POST /admin/create-user` (with `role_slug`)
5. Verify permissions: `GET /pages/my-pages`
