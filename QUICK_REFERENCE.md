# Quick Reference - VendCloud Backend

## Streamlined Workflow (Recommended)

### 1. Create Role with Permissions (One Call)
```bash
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" }
  ]
}
```

### 2. Create User with Role (One Call)
```bash
POST /admin/create-user
{
  "email": "user@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}
```

**Done!** User automatically has all role permissions.

---

## All Admin Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/admin/create-role` | POST | Create role (optional: with permissions) |
| `/admin/create-user` | POST | Create user (optional: with role) |
| `/admin/set-role-pages` | POST | Bulk set role permissions |
| `/admin/set-role-page` | POST | Set single role permission |
| `/admin/set-user-page` | POST | Override user permission |
| `/admin/assign-admin` | POST | Promote user to admin |
| `/admin/roles` | GET | List all roles with permissions |
| `/admin/users` | GET | List all users with roles |

---

## Permission Levels

| Level | Perms Mask | Permissions | Use Case |
|-------|------------|-------------|----------|
| `view` | 2 | Read only | Viewers, reports |
| `admin` | 15 | Full CRUD | Managers, admins |
| `none` | 0 | No access | Revoke access |

---

## Available Pages

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

## Common Role Templates

### Sales Manager
```json
{
  "slug": "sales_manager",
  "label": "Sales Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" }
  ]
}
```

### Finance Team
```json
{
  "slug": "finance_member",
  "label": "Finance Team Member",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "finance", "level": "admin" },
    { "page_slug": "sales", "level": "view" }
  ]
}
```

### Support Agent
```json
{
  "slug": "support_agent",
  "label": "Support Agent",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "support", "level": "admin" },
    { "page_slug": "users", "level": "view" }
  ]
}
```

### Viewer (Read-Only)
```json
{
  "slug": "viewer",
  "label": "Viewer",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "products", "level": "view" }
  ]
}
```

---

## Example Workflow

```bash
# 1. Create manager role with permissions
curl -X POST http://localhost:8080/admin/create-role \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "slug": "manager",
    "label": "Manager",
    "permissions": [
      { "page_slug": "dashboard", "level": "view" },
      { "page_slug": "sales", "level": "admin" }
    ]
  }'

# 2. Create user with manager role
curl -X POST http://localhost:8080/admin/create-user \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "manager@company.com",
    "password": "SecurePass123",
    "email_confirm": true,
    "role_slug": "manager"
  }'

# 3. Verify user's permissions
curl -H "Authorization: Bearer USER_TOKEN" \
  http://localhost:8080/pages/my-pages
```

---

## Permission Priority

1. **Admin role** → Full CRUD (15) on all pages
2. **User-specific permissions** → Override role permissions
3. **Role permissions** → Default from assigned role
4. **No permission** → No access (0)

---

## Documentation

- **[README.md](./README.md)** - Complete API documentation
- **[STREAMLINED_WORKFLOW.md](./STREAMLINED_WORKFLOW.md)** - Detailed examples of streamlined workflow
- **[BULK_PERMISSIONS_EXAMPLES.md](./BULK_PERMISSIONS_EXAMPLES.md)** - Bulk permission setting examples
- **[ROLE_BASED_PERMISSIONS.md](./ROLE_BASED_PERMISSIONS.md)** - Complete RBAC system guide
- **[QUICK_START.md](./QUICK_START.md)** - 5-minute setup guide
- **[MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)** - Database migration guide

---

## Common Commands

```bash
# Development
npm run dev              # Start dev server with hot-reload

# Production
npm run build            # Build TypeScript
npm start                # Start production server

# Admin Setup
npm run seed:admin       # Create initial admin user
npm run assign:admin     # Assign admin role to existing user

# Database
npm run migrate          # Run migrations (limited)
```

---

## Environment Variables

```env
SUPABASE_URL=your-project-url
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
PORT=8080
ALLOWED_ORIGINS=http://localhost:3000,https://your-domain.com
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=securePassword
```

---

## Error Codes

| Code | Category | Description |
|------|----------|-------------|
| AUTH_1xxx | Authentication | Token/auth errors |
| AUTHZ_2xxx | Authorization | Permission errors |
| VAL_3xxx | Validation | Invalid input |
| RES_4xxx | Resource | Not found/exists |
| DB_5xxx | Database | Database errors |
| SYS_9xxx | System | Internal errors |

---

## Quick Tips

✅ **DO:**
- Create roles with permissions in one call
- Create users with roles in one call
- Use bulk endpoints for multiple permissions
- Start with minimum permissions, add as needed
- Document your role structure

❌ **DON'T:**
- Create roles for every permission combination
- Hardcode user IDs in your code
- Skip email confirmation in production
- Use weak passwords
- Share service role key

---

## Need Help?

Check the detailed documentation:
- [STREAMLINED_WORKFLOW.md](./STREAMLINED_WORKFLOW.md) - Step-by-step examples
- [ROLE_BASED_PERMISSIONS.md](./ROLE_BASED_PERMISSIONS.md) - Complete guide
- [QUICK_START.md](./QUICK_START.md) - Fast setup

Or review example use cases in [BULK_PERMISSIONS_EXAMPLES.md](./BULK_PERMISSIONS_EXAMPLES.md).
