# User Metadata Roles

## Overview

The VendCloud backend now stores roles in **both** locations:
1. **`user_metadata`** (in auth.users) - Available in JWT token immediately
2. **`user_roles` table** (in database) - For database queries and permission management

This allows you to access the user's role from the JWT token without querying the database.

---

## How It Works

### When Creating a User
```bash
POST /admin/create-user
{
  "email": "user@example.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}
```

**What happens:**
1. User is created in `auth.users` with `user_metadata: { role: "manager" }`
2. Role is assigned in `user_roles` table
3. Permissions are copied from `role_page_perms` to `user_page_perms`

**Result:** User can access their role from JWT token:
```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "user_metadata": {
    "role": "manager",
    "email_verified": true
  }
}
```

---

## Accessing Role from JWT

### Frontend (Client)
```javascript
// After login with Supabase client
const { data: { user } } = await supabase.auth.getUser();

console.log(user.user_metadata.role); // "manager"
console.log(user.user_metadata.email_verified); // true
```

### Backend (Server)
```typescript
// In middleware (already available via requireAuth)
app.get('/some-route', requireAuth, (req, res) => {
  const userRole = req.user?.user_metadata?.role;
  console.log('User role:', userRole); // "manager"
});
```

---

## API Endpoints

### 1. Create User with Role
```bash
POST /admin/create-user
{
  "email": "user@example.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}
```

**Response:**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "user_metadata": {
      "role": "manager",
      "email_verified": true
    }
  },
  "role_assigned": true,
  "role_slug": "manager",
  "role_permissions_count": 5,
  "user_permissions_granted": 5
}
```

---

### 2. Update User Role (NEW)
```bash
POST /admin/update-user-role
{
  "user_id": "user-uuid",
  "role_slug": "senior_manager"
}
```

**What it does:**
1. Updates `user_metadata.role` in auth.users
2. Updates role in `user_roles` table
3. Deletes old permissions from `user_page_perms`
4. Grants new role's permissions to user

**Response:**
```json
{
  "ok": true,
  "user_id": "uuid",
  "role_slug": "senior_manager",
  "message": "User role updated successfully. User needs to re-login to see changes in JWT."
}
```

**Important:** User must re-login for JWT to reflect the new role!

---

### 3. Assign Admin Role
```bash
POST /admin/assign-admin
{
  "user_id": "user-uuid"
}
```

**Updates:**
- `user_metadata.role` → "admin"
- `user_roles` table → assigns admin role
- User gets full permissions (via admin role logic)

---

## Workflows

### Workflow 1: Create User with Role

```bash
# Step 1: Create role with permissions
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" }
  ]
}

# Step 2: Create user with role
POST /admin/create-user
{
  "email": "manager@example.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}

# Step 3: User logs in
# JWT will contain:
# user_metadata: { role: "manager", email_verified: true }
```

---

### Workflow 2: Promote User to Manager

```bash
# Update existing user's role
POST /admin/update-user-role
{
  "user_id": "existing-user-uuid",
  "role_slug": "manager"
}

# User must re-login to get new role in JWT
```

---

### Workflow 3: Promote User to Admin

```bash
# Make user an admin
POST /admin/assign-admin
{
  "user_id": "user-uuid"
}

# User must re-login to get admin role in JWT
```

---

## JWT Token Structure

### Manager User
```json
{
  "sub": "user-uuid",
  "email": "manager@example.com",
  "aud": "authenticated",
  "role": "authenticated",
  "user_metadata": {
    "role": "manager",
    "email_verified": true
  },
  "iat": 1234567890,
  "exp": 1234571490
}
```

### Admin User
```json
{
  "sub": "user-uuid",
  "email": "admin@example.com",
  "aud": "authenticated",
  "role": "authenticated",
  "user_metadata": {
    "role": "admin",
    "email_verified": true
  },
  "iat": 1234567890,
  "exp": 1234571490
}
```

---

## Frontend Examples

### React with Supabase
```jsx
import { useEffect, useState } from 'react';
import { supabase } from './supabaseClient';

function UserProfile() {
  const [userRole, setUserRole] = useState(null);

  useEffect(() => {
    const getUser = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      setUserRole(user?.user_metadata?.role);
    };
    getUser();
  }, []);

  return (
    <div>
      <h1>Welcome!</h1>
      <p>Your role: {userRole}</p>

      {userRole === 'admin' && (
        <button>Admin Controls</button>
      )}

      {userRole === 'manager' && (
        <button>Manager Dashboard</button>
      )}
    </div>
  );
}
```

### Vue with Supabase
```vue
<template>
  <div>
    <h1>Welcome!</h1>
    <p>Your role: {{ userRole }}</p>

    <button v-if="userRole === 'admin'">Admin Controls</button>
    <button v-if="userRole === 'manager'">Manager Dashboard</button>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { supabase } from './supabaseClient';

const userRole = ref(null);

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser();
  userRole.value = user?.user_metadata?.role;
});
</script>
```

### Angular with Supabase
```typescript
import { Component, OnInit } from '@angular/core';
import { supabase } from './supabaseClient';

@Component({
  selector: 'app-user-profile',
  template: `
    <div>
      <h1>Welcome!</h1>
      <p>Your role: {{ userRole }}</p>

      <button *ngIf="userRole === 'admin'">Admin Controls</button>
      <button *ngIf="userRole === 'manager'">Manager Dashboard</button>
    </div>
  `
})
export class UserProfileComponent implements OnInit {
  userRole: string | null = null;

  async ngOnInit() {
    const { data: { user } } = await supabase.auth.getUser();
    this.userRole = user?.user_metadata?.role;
  }
}
```

---

## Backend Route Protection

### Check Role in Middleware
```typescript
import { Request, Response, NextFunction } from 'express';

function requireRole(role: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    const userRole = req.user?.user_metadata?.role;

    if (userRole !== role) {
      return res.status(403).json({
        error: 'Forbidden: Insufficient role'
      });
    }

    next();
  };
}

// Usage
app.get('/admin/dashboard', requireAuth, requireRole('admin'), (req, res) => {
  res.json({ message: 'Welcome to admin dashboard' });
});
```

### Check Multiple Roles
```typescript
function requireAnyRole(allowedRoles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const userRole = req.user?.user_metadata?.role;

    if (!allowedRoles.includes(userRole)) {
      return res.status(403).json({
        error: 'Forbidden: Insufficient role'
      });
    }

    next();
  };
}

// Usage
app.get('/management/reports',
  requireAuth,
  requireAnyRole(['admin', 'manager', 'analyst']),
  (req, res) => {
    res.json({ message: 'Reports data' });
  }
);
```

---

## Important Notes

### 1. User Must Re-Login for Metadata Changes
When you update a user's role with `/admin/update-user-role` or `/admin/assign-admin`, the change is saved to the database immediately, but the JWT token is NOT updated until the user logs in again.

**Solutions:**
- Tell user to re-login
- Force logout on frontend and redirect to login
- Use Supabase's `auth.refreshSession()` (may not update metadata immediately)

### 2. Two Sources of Truth
The role is stored in two places:
- **`user_metadata`**: For quick access in JWT (fast, cached)
- **`user_roles` table**: For database queries and permission management (source of truth)

Always update BOTH when changing roles!

### 3. Role in Metadata vs Database Permissions
- `user_metadata.role` is for display and basic authorization checks
- `user_page_perms` and `user_effective_page_perms` are for actual permission enforcement

Don't rely solely on `user_metadata.role` for critical security decisions!

---

## Troubleshooting

### User's JWT doesn't show new role
**Problem:** Updated user's role but JWT still shows old role.

**Solution:** User must log out and log back in to get new JWT.

### Role is null in user_metadata
**Problem:** Created user without `role_slug` parameter.

**Solution:**
```bash
# Option 1: Update existing user
POST /admin/update-user-role
{
  "user_id": "uuid",
  "role_slug": "manager"
}

# Option 2: Assign admin role
POST /admin/assign-admin
{
  "user_id": "uuid"
}
```

### User has role in metadata but no permissions
**Problem:** Role exists in metadata but user has no page permissions.

**Solution:** See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - likely the role had no permissions when user was created.

---

## Migration from Old Users

If you have existing users without roles in metadata:

### Option 1: Update All Users (SQL)
```sql
-- Update user_metadata for all users who have roles
UPDATE auth.users u
SET raw_user_meta_data = jsonb_set(
  COALESCE(raw_user_meta_data, '{}'::jsonb),
  '{role}',
  to_jsonb(r.slug)
)
FROM user_roles ur
JOIN roles r ON r.id = ur.role_id
WHERE u.id = ur.user_id;
```

### Option 2: Update Specific User via API
```bash
# For each user, call:
POST /admin/update-user-role
{
  "user_id": "uuid",
  "role_slug": "their_current_role"
}
```

---

## Summary

✅ **Benefits:**
- Role available in JWT immediately
- No database query needed to get user's role
- Works like admin user metadata
- Frontend can display role-specific UI instantly

✅ **Use Cases:**
- Show/hide UI elements based on role
- Route guards in frontend
- Basic authorization checks
- User profile display

✅ **Remember:**
- Update both metadata AND database when changing roles
- User must re-login to see metadata changes in JWT
- Use database permissions for actual access control
- Metadata is for convenience, not security

---

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/admin/create-user` | POST | Create user with role in metadata |
| `/admin/update-user-role` | POST | Update existing user's role (metadata + database) |
| `/admin/assign-admin` | POST | Promote user to admin (metadata + database) |
| `/admin/users` | GET | List all users (includes roles) |
| `/pages/my-pages` | GET | Get user's page permissions |

---

For more information:
- [README.md](./README.md) - Complete API documentation
- [STREAMLINED_WORKFLOW.md](./STREAMLINED_WORKFLOW.md) - Workflow examples
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Fix permission issues
