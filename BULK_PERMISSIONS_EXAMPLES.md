# Bulk Permission Setting Examples

Complete guide and examples for using the **bulk permission endpoint** to efficiently set up roles.

## Why Use Bulk Permissions?

### ❌ Old Way (Multiple API Calls)
```bash
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "dashboard", "level": "view" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "sales", "level": "admin" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "products", "level": "admin" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "inventory", "level": "admin" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "finance", "level": "view" }
```
**5 API calls!** 😫

### ✅ New Way (One Bulk Call)
```bash
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" }
  ]
}
```
**1 API call!** 🎉

---

## API Endpoint

### `POST /admin/set-role-pages` (Bulk)

**Description:** Set permissions for a role on multiple pages in a single call.

**Request Body:**
```typescript
{
  role_slug: string;                                    // Role to configure
  permissions: Array<{
    page_slug: string;                                  // Page to grant access to
    level: 'view' | 'admin' | 'none';                  // Permission level
  }>;
}
```

**Response:**
```json
{
  "ok": true,
  "role_slug": "manager",
  "permissions_set": 5,
  "permissions_removed": 0,
  "details": [
    { "page_slug": "dashboard", "level": "view", "perms_mask": 2 },
    { "page_slug": "sales", "level": "admin", "perms_mask": 15 },
    { "page_slug": "products", "level": "admin", "perms_mask": 15 },
    { "page_slug": "inventory", "level": "admin", "perms_mask": 15 },
    { "page_slug": "finance", "level": "view", "perms_mask": 2 }
  ]
}
```

**Permissions Required:** UPDATE on "settings" page

---

## Complete Examples

### Example 1: Sales Manager Role

**Goal:** Create a role for sales managers with:
- View dashboard
- Full control over sales and products
- Read-only access to finance

```bash
# 1. Create role
POST /admin/create-role
{
  "slug": "sales_manager",
  "label": "Sales Manager"
}

# 2. Set all permissions at once
POST /admin/set-role-pages
{
  "role_slug": "sales_manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" },
    { "page_slug": "marketing", "level": "view" }
  ]
}

# 3. Create user with role
POST /admin/create-user
{
  "email": "sales.manager@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "sales_manager"
}
```

**Result:** User automatically has:
- ✅ Dashboard (view)
- ✅ Sales (full control)
- ✅ Products (full control)
- ✅ Inventory (full control)
- ✅ Finance (read-only)
- ✅ Marketing (read-only)

---

### Example 2: Operations Manager

**Goal:** Full access to operations, limited access to others

```bash
POST /admin/create-role
{
  "slug": "ops_manager",
  "label": "Operations Manager"
}

POST /admin/set-role-pages
{
  "role_slug": "ops_manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "machines", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "support", "level": "admin" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "finance", "level": "view" }
  ]
}
```

---

### Example 3: Finance Team Member

**Goal:** Full finance access, read-only everything else

```bash
POST /admin/create-role
{
  "slug": "finance_member",
  "label": "Finance Team Member"
}

POST /admin/set-role-pages
{
  "role_slug": "finance_member",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "finance", "level": "admin" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "products", "level": "view" },
    { "page_slug": "inventory", "level": "view" }
  ]
}
```

---

### Example 4: Customer Support Agent

**Goal:** Limited access to support tools and view-only access to customer data

```bash
POST /admin/create-role
{
  "slug": "support_agent",
  "label": "Support Agent"
}

POST /admin/set-role-pages
{
  "role_slug": "support_agent",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "support", "level": "admin" },
    { "page_slug": "users", "level": "view" },
    { "page_slug": "products", "level": "view" },
    { "page_slug": "machines", "level": "view" }
  ]
}
```

---

### Example 5: Read-Only Viewer

**Goal:** Can see everything but cannot modify anything

```bash
POST /admin/create-role
{
  "slug": "viewer",
  "label": "Viewer"
}

POST /admin/set-role-pages
{
  "role_slug": "viewer",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "machines", "level": "view" },
    { "page_slug": "products", "level": "view" },
    { "page_slug": "inventory", "level": "view" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "finance", "level": "view" },
    { "page_slug": "support", "level": "view" },
    { "page_slug": "marketing", "level": "view" }
  ]
}
```

---

### Example 6: Department Head (Executive)

**Goal:** Full access to most things except system settings

```bash
POST /admin/create-role
{
  "slug": "department_head",
  "label": "Department Head"
}

POST /admin/set-role-pages
{
  "role_slug": "department_head",
  "permissions": [
    { "page_slug": "dashboard", "level": "admin" },
    { "page_slug": "machines", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "finance", "level": "admin" },
    { "page_slug": "support", "level": "admin" },
    { "page_slug": "marketing", "level": "admin" },
    { "page_slug": "users", "level": "view" }
  ]
}
```

---

## Advanced: Revoking Permissions

Use `"level": "none"` to remove permissions:

```bash
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "finance", "level": "none" },     // Remove finance access
    { "page_slug": "settings", "level": "none" }     // Remove settings access
  ]
}
```

---

## Updating Existing Permissions

The bulk endpoint **replaces** permissions for the specified pages:

```bash
# Initial setup
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "sales", "level": "view" }
  ]
}

# Later: upgrade to admin
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "sales", "level": "admin" }     // Upgrades from view to admin
  ]
}
```

---

## Complete Workflow: Setting Up a New Organization

```bash
# Step 1: Create all roles
POST /admin/create-role { "slug": "ceo", "label": "CEO" }
POST /admin/create-role { "slug": "manager", "label": "Manager" }
POST /admin/create-role { "slug": "employee", "label": "Employee" }
POST /admin/create-role { "slug": "viewer", "label": "Viewer" }

# Step 2: Configure permissions (in parallel if your tool supports it)

# CEO permissions
POST /admin/set-role-pages
{
  "role_slug": "ceo",
  "permissions": [
    { "page_slug": "dashboard", "level": "admin" },
    { "page_slug": "machines", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "finance", "level": "admin" },
    { "page_slug": "support", "level": "admin" },
    { "page_slug": "marketing", "level": "admin" },
    { "page_slug": "users", "level": "view" }
  ]
}

# Manager permissions
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" }
  ]
}

# Employee permissions
POST /admin/set-role-pages
{
  "role_slug": "employee",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "products", "level": "view" }
  ]
}

# Viewer permissions
POST /admin/set-role-pages
{
  "role_slug": "viewer",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" }
  ]
}

# Step 3: Create users with roles
POST /admin/create-user
{
  "email": "ceo@company.com",
  "password": "SecurePass123",
  "role_slug": "ceo"
}

POST /admin/create-user
{
  "email": "manager1@company.com",
  "password": "SecurePass123",
  "role_slug": "manager"
}

POST /admin/create-user
{
  "email": "employee1@company.com",
  "password": "SecurePass123",
  "role_slug": "employee"
}
```

---

## Tips & Best Practices

### 1. Use Descriptive Role Names
```bash
✅ Good: "sales_manager", "finance_analyst", "support_agent"
❌ Bad: "role1", "manager", "user2"
```

### 2. Group Similar Permissions
```bash
# All view permissions together
POST /admin/set-role-pages
{
  "role_slug": "analyst",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "products", "level": "view" },
    { "page_slug": "finance", "level": "view" }
  ]
}
```

### 3. Start with Minimum Permissions
```bash
# Give users minimum access first
# Then upgrade specific users as needed
POST /admin/set-role-pages
{
  "role_slug": "employee",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" }
  ]
}

# Later: override for specific user
POST /admin/set-user-page
{
  "user_id": "uuid",
  "page_slug": "sales",
  "level": "admin"
}
```

### 4. Document Your Roles
```json
// Keep a roles.json in your repo
{
  "sales_manager": {
    "label": "Sales Manager",
    "description": "Manages sales team and has full access to sales data",
    "permissions": [
      { "page_slug": "dashboard", "level": "view" },
      { "page_slug": "sales", "level": "admin" },
      { "page_slug": "products", "level": "admin" }
    ]
  }
}
```

---

## Error Handling

### Invalid Page Slug
```json
// Request
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "nonexistent", "level": "view" }
  ]
}

// Response (400 Bad Request)
{
  "error": "Invalid page slugs: nonexistent"
}
```

### Invalid Level
```json
// Request
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "sales", "level": "superuser" }  // Invalid!
  ]
}

// Response (400 Bad Request)
{
  "error": "Invalid level \"superuser\". Must be: view, admin, or none"
}
```

### Role Not Found
```json
// Request
{
  "role_slug": "nonexistent_role",
  "permissions": [...]
}

// Response (400 Bad Request)
{
  "error": "Role \"nonexistent_role\" not found"
}
```

---

## Comparison: Bulk vs Single

| Feature | `/set-role-page` (Single) | `/set-role-pages` (Bulk) |
|---------|---------------------------|--------------------------|
| API Calls | 1 per page | 1 total |
| Speed | Slow for many pages | Fast |
| Validation | Per call | All at once |
| Error Handling | Immediate per page | All or nothing* |
| Use Case | Quick fixes | Initial setup |

*Note: Bulk endpoint validates all inputs first, then applies changes.

---

## Testing Your Permissions

After setting up roles, test them:

```bash
# 1. Create test user with role
POST /admin/create-user
{
  "email": "test.manager@company.com",
  "password": "TestPass123",
  "role_slug": "manager"
}

# 2. Login as that user (get JWT token)

# 3. Check their permissions
GET /pages/my-pages
Authorization: Bearer <test-user-token>

# 4. Verify correct pages and perms_mask values
```

---

## Quick Reference

### All Available Pages
```javascript
[
  'dashboard',
  'machines',
  'products',
  'inventory',
  'sales',
  'finance',
  'support',
  'marketing',
  'users',
  'settings'
]
```

### Permission Levels
```javascript
'view'  → perms_mask: 2   → Read only
'admin' → perms_mask: 15  → Full CRUD
'none'  → perms_mask: 0   → No access (removes permission)
```

### Common Patterns
```javascript
// Executive: Full access minus settings
['dashboard', 'machines', 'products', 'inventory', 'sales',
 'finance', 'support', 'marketing', 'users'].map(page =>
  ({ page_slug: page, level: 'admin' }))

// Manager: Department control + read elsewhere
[
  { page_slug: 'dashboard', level: 'view' },
  { page_slug: 'sales', level: 'admin' },
  { page_slug: 'products', level: 'admin' },
  { page_slug: 'finance', level: 'view' }
]

// Employee: Limited read access
[
  { page_slug: 'dashboard', level: 'view' },
  { page_slug: 'sales', level: 'view' }
]

// Viewer: Everything read-only
['dashboard', 'machines', 'products', 'inventory', 'sales',
 'finance', 'support', 'marketing'].map(page =>
  ({ page_slug: page, level: 'view' }))
```

---

## Summary

✅ **Use `/set-role-pages` (bulk)** for:
- Initial role setup
- Multiple permission changes
- Faster configuration

✅ **Use `/set-role-page` (single)** for:
- Quick single permission change
- One-off adjustments
- Testing

**Pro Tip:** Set up roles with bulk endpoint, adjust individual users with `/set-user-page` if needed! 🎯
