# Quick Start Guide - Role-Based Permissions

Get up and running with the VendCloud role-based permissions system in 5 minutes.

## Prerequisites

- ✅ Supabase project set up
- ✅ `.env` file configured
- ✅ Initial migration applied (20250101000000_initial_schema.sql)

---

## Step 1: Apply Role Permissions Migration (2 min)

### Option A: Supabase Dashboard
1. Open Supabase Dashboard → **SQL Editor**
2. Copy `supabase/migrations/20250102000000_role_page_permissions.sql`
3. Paste and click **Run**
4. Verify: Check if `role_page_perms` table exists in **Table Editor**

### Option B: Supabase CLI
```bash
supabase db push
```

---

## Step 2: Create Your First Admin (1 min)

### Manual Method (Recommended)
1. Supabase Dashboard → **Authentication** → **Users**
2. Click **"Add user"** → **"Create new user"**
3. Enter your email and password
4. Check **"Auto Confirm User"**
5. Click **Create user**

Then assign admin role:
```bash
npm run assign:admin
```

---

## Step 3: Test the API (1 min)

### Get Your Access Token
Login via Supabase Auth or your frontend to get JWT token.

### Test Endpoints
```bash
# Check your permissions
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/pages/my-pages

# Should return all pages with perms_mask = 15 (admin has full access)
```

---

## Step 4: Create Roles and Permissions (1 min)

### Create a Manager Role
```bash
curl -X POST http://localhost:8080/admin/create-role \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "slug": "manager",
    "label": "Manager"
  }'
```

### Give Managers Permissions (Bulk - Recommended)
```bash
# Set multiple permissions in ONE call
curl -X POST http://localhost:8080/admin/set-role-pages \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "role_slug": "manager",
    "permissions": [
      { "page_slug": "dashboard", "level": "view" },
      { "page_slug": "sales", "level": "admin" },
      { "page_slug": "products", "level": "admin" },
      { "page_slug": "finance", "level": "view" },
      { "page_slug": "inventory", "level": "admin" }
    ]
  }'
```

**Or set one at a time:**
```bash
# Full access to sales
curl -X POST http://localhost:8080/admin/set-role-page \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "role_slug": "manager",
    "page_slug": "sales",
    "level": "admin"
  }'
```

### Create a Manager User
```bash
curl -X POST http://localhost:8080/admin/create-user \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "manager@company.com",
    "password": "SecurePass123",
    "email_confirm": true,
    "role_slug": "manager"
  }'
```

**✅ Done!** The user automatically has:
- Full CRUD on sales (15)
- Read-only on finance (2)
- No access to other pages

---

## Common Workflows

### Workflow 1: Add New Employee

```bash
# 1. Create viewer role (if not exists)
POST /admin/create-role
{
  "slug": "employee",
  "label": "Employee"
}

# 2. Set permissions
POST /admin/set-role-page
{ "role_slug": "employee", "page_slug": "dashboard", "level": "view" }

# 3. Create user with role
POST /admin/create-user
{
  "email": "newemployee@company.com",
  "password": "TempPass123",
  "email_confirm": true,
  "role_slug": "employee"
}
```

### Workflow 2: Promote User to Manager

```bash
# Option 1: Create new user as manager
POST /admin/create-user
{
  "email": "user@company.com",
  "password": "SecurePass123",
  "role_slug": "manager"
}

# Option 2: Update existing user's role (manual SQL for now)
# In Supabase SQL Editor:
UPDATE user_roles
SET role_id = (SELECT id FROM roles WHERE slug = 'manager')
WHERE user_id = 'user-uuid';
```

### Workflow 3: Give Special Access

```bash
# Manager needs admin access to finance (normally read-only)
POST /admin/set-user-page
{
  "user_id": "manager-uuid",
  "page_slug": "finance",
  "level": "admin"
}
```

---

## View System Status

### List All Roles
```bash
GET /admin/roles
```

Returns:
```json
{
  "roles": [
    {
      "id": 1,
      "slug": "admin",
      "label": "Admin",
      "permissions": [...]
    },
    {
      "id": 2,
      "slug": "manager",
      "label": "Manager",
      "permissions": [
        { "page_slug": "sales", "perms_mask": 15 },
        { "page_slug": "finance", "perms_mask": 2 }
      ]
    }
  ]
}
```

### List All Users
```bash
GET /admin/users
```

Returns:
```json
{
  "users": [
    {
      "id": "uuid",
      "email": "manager@company.com",
      "role": { "slug": "manager", "label": "Manager" }
    }
  ]
}
```

### Check User's Permissions
```bash
GET /pages/my-pages
```

Returns:
```json
{
  "pages": [
    { "page_slug": "sales", "perms_mask": 15 },
    { "page_slug": "finance", "perms_mask": 2 }
  ]
}
```

---

## Permission Levels Cheat Sheet

| Level | Bitmask | Permissions | Use Case |
|-------|---------|-------------|----------|
| `none` | 0 | No access | Revoke access |
| `view` | 2 | Read only | Viewers, reports |
| `admin` | 15 | Full CRUD | Managers, admins |

### Bitmask Details
```
C (Create) = 1
R (Read)   = 2
U (Update) = 4
D (Delete) = 8

view  = R           = 2
admin = C+R+U+D     = 15
custom = C+R        = 3
custom = R+U        = 6
```

---

## Available Pages

Default pages from migration:
- `dashboard` - Dashboard
- `machines` - Machines
- `products` - Products
- `inventory` - Inventory
- `sales` - Sales
- `finance` - Finance
- `support` - Support
- `marketing` - Marketing / Signage
- `users` - Users
- `settings` - Settings

---

## Troubleshooting

### ❌ 401 Unauthorized
- Check your JWT token is valid
- Token format: `Authorization: Bearer <token>`

### ❌ 403 Forbidden
- User doesn't have required permissions
- Check: `GET /pages/my-pages`
- Admin needs UPDATE on "settings" for admin endpoints

### ❌ Role Not Found
- Create role first: `POST /admin/create-role`
- Check available roles: `GET /admin/roles`

### ❌ User Not Getting Permissions
- Verify role assignment succeeded
- Check SQL: `SELECT * FROM user_roles WHERE user_id = 'uuid'`
- Check trigger exists: `SELECT * FROM pg_trigger WHERE tgname = 'trigger_grant_role_permissions'`

---

## Next Steps

1. **Read Full Guide**: See [ROLE_BASED_PERMISSIONS.md](./ROLE_BASED_PERMISSIONS.md)
2. **Migration Guide**: See [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)
3. **API Docs**: See [README.md](./README.md)

---

## Quick Reference: All Admin Endpoints

```bash
# Roles
POST   /admin/create-role       # Create role
GET    /admin/roles             # List all roles
POST   /admin/set-role-page     # Set role permissions on page

# Users
POST   /admin/create-user       # Create user (with optional role)
GET    /admin/users             # List all users
POST   /admin/set-user-page     # Override user permissions
POST   /admin/assign-admin      # Promote user to admin

# Non-Admin
GET    /pages/my-pages          # Get current user's permissions
GET    /health                  # Health check
```

---

**Need Help?**
- Check [ROLE_BASED_PERMISSIONS.md](./ROLE_BASED_PERMISSIONS.md) for detailed examples
- Check [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) for database issues
- Check application logs for errors
