# Streamlined Workflow - Create Roles & Users

Complete examples showing the **streamlined workflow** for creating roles with permissions and users with roles in a single API call.

---

## Overview

### New Workflow (Recommended)

**Create Role + Permissions in ONE call:**
```bash
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" }
  ]
}
```

**Create User + Assign Role in ONE call:**
```bash
POST /admin/create-user
{
  "email": "manager@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}
```

### Old Workflow (Still Supported)

1. Create role
2. Set permissions (one by one OR bulk)
3. Create user
4. Assign role to user

---

## Example 1: Sales Manager

### Step 1: Create Role with Permissions
```bash
POST /admin/create-role
{
  "slug": "sales_manager",
  "label": "Sales Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" },
    { "page_slug": "marketing", "level": "view" }
  ]
}
```

**Response:**
```json
{
  "role": {
    "id": 2,
    "slug": "sales_manager",
    "label": "Sales Manager",
    "created_at": "2025-01-02T10:00:00Z"
  },
  "permissions_assigned": 6,
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" },
    { "page_slug": "marketing", "level": "view" }
  ]
}
```

### Step 2: Create User with Role
```bash
POST /admin/create-user
{
  "email": "john.doe@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "sales_manager"
}
```

**Response:**
```json
{
  "user": {
    "id": "uuid-123",
    "email": "john.doe@company.com",
    "created_at": "2025-01-02T10:05:00Z"
  },
  "role_assigned": true,
  "role_slug": "sales_manager"
}
```

**Done!** User automatically has:
- Dashboard (view - perms_mask: 2)
- Sales (admin - perms_mask: 15)
- Products (admin - perms_mask: 15)
- Inventory (admin - perms_mask: 15)
- Finance (view - perms_mask: 2)
- Marketing (view - perms_mask: 2)

---

## Example 2: Finance Team Member

### Step 1: Create Role with Permissions
```bash
POST /admin/create-role
{
  "slug": "finance_member",
  "label": "Finance Team Member",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "finance", "level": "admin" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "products", "level": "view" },
    { "page_slug": "inventory", "level": "view" }
  ]
}
```

### Step 2: Create User with Role
```bash
POST /admin/create-user
{
  "email": "finance@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "finance_member"
}
```

---

## Example 3: Customer Support Agent

### Step 1: Create Role with Permissions
```bash
POST /admin/create-role
{
  "slug": "support_agent",
  "label": "Support Agent",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "support", "level": "admin" },
    { "page_slug": "users", "level": "view" },
    { "page_slug": "products", "level": "view" },
    { "page_slug": "machines", "level": "view" }
  ]
}
```

### Step 2: Create Users with Role
```bash
# Agent 1
POST /admin/create-user
{
  "email": "support1@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "support_agent"
}

# Agent 2
POST /admin/create-user
{
  "email": "support2@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "support_agent"
}
```

**Both agents automatically get the same permissions!**

---

## Example 4: Read-Only Viewer

### Step 1: Create Role with Permissions
```bash
POST /admin/create-role
{
  "slug": "viewer",
  "label": "Viewer",
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

### Step 2: Create User with Role
```bash
POST /admin/create-user
{
  "email": "viewer@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "viewer"
}
```

---

## Example 5: Department Head (Executive)

### Step 1: Create Role with Permissions
```bash
POST /admin/create-role
{
  "slug": "department_head",
  "label": "Department Head",
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

### Step 2: Create User with Role
```bash
POST /admin/create-user
{
  "email": "head@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "department_head"
}
```

---

## Example 6: Creating Role Without Permissions

You can still create a role without permissions and add them later:

```bash
# Create empty role
POST /admin/create-role
{
  "slug": "new_role",
  "label": "New Role"
}

# Add permissions later (bulk)
POST /admin/set-role-pages
{
  "role_slug": "new_role",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" }
  ]
}
```

---

## Example 7: Creating User Without Role

You can create a user without a role and assign it later:

```bash
# Create user without role
POST /admin/create-user
{
  "email": "user@company.com",
  "password": "SecurePass123",
  "email_confirm": true
}

# Assign role later (manual SQL for now)
# In Supabase SQL Editor:
INSERT INTO user_roles (user_id, role_id)
VALUES (
  'user-uuid',
  (SELECT id FROM roles WHERE slug = 'manager')
);
```

---

## Complete Onboarding Flow

### Setup Organization Roles (One-Time)

```bash
# 1. CEO Role
POST /admin/create-role
{
  "slug": "ceo",
  "label": "CEO",
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

# 2. Manager Role
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" },
    { "page_slug": "products", "level": "admin" },
    { "page_slug": "inventory", "level": "admin" },
    { "page_slug": "finance", "level": "view" }
  ]
}

# 3. Employee Role
POST /admin/create-role
{
  "slug": "employee",
  "label": "Employee",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "view" },
    { "page_slug": "products", "level": "view" }
  ]
}

# 4. Viewer Role
POST /admin/create-role
{
  "slug": "viewer",
  "label": "Viewer",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" }
  ]
}
```

### Add Team Members

```bash
# CEO
POST /admin/create-user
{
  "email": "ceo@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "ceo"
}

# Manager 1
POST /admin/create-user
{
  "email": "manager1@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}

# Manager 2
POST /admin/create-user
{
  "email": "manager2@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}

# Employee 1
POST /admin/create-user
{
  "email": "employee1@company.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "employee"
}
```

---

## Error Handling

### Invalid Page Slug
```json
// Request
POST /admin/create-role
{
  "slug": "test",
  "label": "Test",
  "permissions": [
    { "page_slug": "nonexistent", "level": "view" }
  ]
}

// Response (201 - Role created, warning shown)
{
  "role": { "id": 5, "slug": "test", "label": "Test" },
  "warning": "Role created but some pages are invalid: nonexistent"
}
```

### Invalid Permission Level
```json
// Request
POST /admin/create-role
{
  "slug": "test",
  "label": "Test",
  "permissions": [
    { "page_slug": "dashboard", "level": "superuser" }
  ]
}

// Response (400 Bad Request)
{
  "error": "Invalid level \"superuser\". Must be: view or admin"
}
```

### Role Already Exists
```json
// Request
POST /admin/create-role
{
  "slug": "admin",
  "label": "Admin"
}

// Response (400 Bad Request)
{
  "error": "Role with slug \"admin\" already exists"
}
```

### User Creation with Non-Existent Role
```json
// Request
POST /admin/create-user
{
  "email": "user@company.com",
  "password": "SecurePass123",
  "role_slug": "nonexistent"
}

// Response (400 Bad Request)
{
  "error": "Role \"nonexistent\" does not exist"
}
```

---

## Verify Permissions

After creating roles and users, verify permissions:

```bash
# 1. List all roles with permissions
GET /admin/roles

# 2. List all users with roles
GET /admin/users

# 3. Login as user and check their permissions
GET /pages/my-pages
Authorization: Bearer <user-token>
```

---

## Benefits of Streamlined Workflow

### Before (3 API Calls)
```bash
POST /admin/create-role { "slug": "manager", "label": "Manager" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "sales", "level": "admin" }
POST /admin/set-role-page { "role_slug": "manager", "page_slug": "finance", "level": "view" }
```

### After (1 API Call)
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

**Advantages:**
- ✅ Fewer API calls
- ✅ Atomic operation (all or nothing)
- ✅ Faster role setup
- ✅ Less error-prone
- ✅ Better user experience

---

## Summary

**Streamlined workflow:**
1. **Create Role + Permissions** in one call → `POST /admin/create-role` with `permissions` array
2. **Create User + Assign Role** in one call → `POST /admin/create-user` with `role_slug`
3. **User automatically gets permissions** via database trigger

**Old workflow still supported:**
- Create role → Set permissions (bulk or single) → Create user → Assign role

Choose the workflow that fits your use case!
