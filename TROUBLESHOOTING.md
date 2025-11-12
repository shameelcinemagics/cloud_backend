# Troubleshooting Guide

## Issue: User Created with Role but No Permissions

### Symptoms
- Created user with `role_slug` via `/admin/create-user`
- User appears in `auth.users` table
- User has entry in `user_roles` table
- **But:** User has NO entries in `user_page_perms` table
- **Result:** User cannot access any pages

### Root Causes

#### 1. Role Has No Permissions
**Problem:** The role exists but has no permissions defined in `role_page_perms` table.

**Check:**
```sql
-- Check if role has permissions
SELECT r.slug, r.label, COUNT(rpp.page_id) as permission_count
FROM roles r
LEFT JOIN role_page_perms rpp ON rpp.role_id = r.id
WHERE r.slug = 'YOUR_ROLE_SLUG'
GROUP BY r.id, r.slug, r.label;
```

**Fix:** Add permissions to the role first:
```bash
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" }
  ]
}
```

Or use the streamlined approach:
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

#### 2. Trigger Doesn't Exist
**Problem:** Migration `20250102000000_role_page_permissions.sql` wasn't applied.

**Check:**
```sql
-- Check if trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'trigger_grant_role_permissions';

-- Check if function exists
SELECT * FROM pg_proc WHERE proname = 'grant_role_permissions_to_user';
```

**Or use diagnostic endpoint:**
```bash
GET /admin/check-trigger
```

**Fix:** Apply the migration:
```sql
-- Run this in Supabase SQL Editor
-- Copy contents of: supabase/migrations/20250102000000_role_page_permissions.sql
```

#### 3. Trigger Failed Silently
**Problem:** Trigger exists but failed due to RLS policies or permissions.

**Check:** Look at the enhanced response from `/admin/create-user`:
```json
{
  "user": { ... },
  "role_assigned": true,
  "role_slug": "manager",
  "role_permissions_count": 5,
  "user_permissions_granted": 0,  // ⚠️ Should match role_permissions_count
  "debug": {
    "role_had_permissions": true,
    "trigger_granted_permissions": false,  // ⚠️ Trigger failed!
    "trigger_worked": false
  }
}
```

**Fix:** Manually grant permissions:
```sql
-- Manually copy role permissions to user
INSERT INTO user_page_perms (user_id, page_id, perms_mask)
SELECT
  'USER_UUID',  -- Replace with actual user ID
  rpp.page_id,
  rpp.perms_mask
FROM role_page_perms rpp
WHERE rpp.role_id = (SELECT id FROM roles WHERE slug = 'ROLE_SLUG')
ON CONFLICT (user_id, page_id) DO NOTHING;
```

#### 4. Workflow Issue: Created User Before Role Had Permissions
**Problem:** You created the user with role BEFORE adding permissions to that role.

**Example of wrong order:**
```bash
# Step 1: Create role (no permissions yet)
POST /admin/create-role { "slug": "manager", "label": "Manager" }

# Step 2: Create user with role (trigger copies 0 permissions)
POST /admin/create-user { "email": "user@example.com", "role_slug": "manager" }

# Step 3: Add permissions to role (too late - user already created)
POST /admin/set-role-pages { "role_slug": "manager", "permissions": [...] }
```

**Fix:** Either:
1. **Delete and recreate user** (after role has permissions)
2. **Manually grant permissions** (SQL above)
3. **Use streamlined workflow** (create role with permissions, then create user)

---

## Manual Fix for Existing Users

### Step 1: Verify Role Has Permissions
```sql
-- Check role permissions
SELECT
  r.slug as role_slug,
  p.slug as page_slug,
  rpp.perms_mask
FROM roles r
JOIN role_page_perms rpp ON rpp.role_id = r.id
JOIN pages p ON p.id = rpp.page_id
WHERE r.slug = 'YOUR_ROLE_SLUG';
```

If no results, add permissions to role first!

### Step 2: Find Users Without Permissions
```sql
-- Find users with role but no permissions
SELECT
  u.id as user_id,
  u.email,
  r.slug as role_slug,
  COUNT(upp.page_id) as user_perms_count
FROM auth.users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
LEFT JOIN user_page_perms upp ON upp.user_id = u.id
WHERE r.slug = 'YOUR_ROLE_SLUG'
GROUP BY u.id, u.email, r.slug
HAVING COUNT(upp.page_id) = 0;  -- Users with 0 permissions
```

### Step 3: Grant Permissions to Affected Users
```sql
-- Manually grant role permissions to specific user
INSERT INTO user_page_perms (user_id, page_id, perms_mask)
SELECT
  'USER_UUID_HERE',  -- ⚠️ Replace with actual user UUID
  rpp.page_id,
  rpp.perms_mask
FROM role_page_perms rpp
WHERE rpp.role_id = (SELECT id FROM roles WHERE slug = 'ROLE_SLUG_HERE')
ON CONFLICT (user_id, page_id) DO NOTHING;
```

### Step 4: Verify Permissions Were Granted
```sql
-- Check user's permissions
SELECT
  u.email,
  p.slug as page_slug,
  upp.perms_mask
FROM auth.users u
JOIN user_page_perms upp ON upp.user_id = u.id
JOIN pages p ON p.id = upp.page_id
WHERE u.id = 'USER_UUID_HERE';
```

---

## Bulk Fix: Grant Permissions to All Users with Role

If multiple users are affected:

```sql
-- Grant permissions to ALL users with a specific role
INSERT INTO user_page_perms (user_id, page_id, perms_mask)
SELECT
  ur.user_id,
  rpp.page_id,
  rpp.perms_mask
FROM user_roles ur
JOIN role_page_perms rpp ON rpp.role_id = ur.role_id
JOIN roles r ON r.id = ur.role_id
WHERE r.slug = 'ROLE_SLUG_HERE'
ON CONFLICT (user_id, page_id) DO NOTHING;
```

---

## Verify User's Effective Permissions

### Method 1: Check user_effective_page_perms View
```sql
SELECT * FROM user_effective_page_perms
WHERE user_id = 'USER_UUID'
ORDER BY page_slug;
```

### Method 2: Login and Call /pages/my-pages
```bash
# Login as the user to get JWT token
# Then call:
GET /pages/my-pages
Authorization: Bearer USER_JWT_TOKEN
```

---

## Prevention: Use Correct Workflow

### ✅ Correct Workflow (Streamlined)
```bash
# 1. Create role WITH permissions
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" }
  ]
}

# 2. Create user with role
POST /admin/create-user
{
  "email": "user@example.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}

# ✅ User automatically has permissions!
```

### ✅ Alternative Workflow (Step by Step)
```bash
# 1. Create role
POST /admin/create-role
{
  "slug": "manager",
  "label": "Manager"
}

# 2. Add permissions to role BEFORE creating users
POST /admin/set-role-pages
{
  "role_slug": "manager",
  "permissions": [
    { "page_slug": "dashboard", "level": "view" },
    { "page_slug": "sales", "level": "admin" }
  ]
}

# 3. NOW create users with this role
POST /admin/create-user
{
  "email": "user@example.com",
  "password": "SecurePass123",
  "email_confirm": true,
  "role_slug": "manager"
}
```

### ❌ Wrong Workflow
```bash
# 1. Create role (no permissions)
POST /admin/create-role { "slug": "manager", "label": "Manager" }

# 2. Create user with role (gets 0 permissions)
POST /admin/create-user { "email": "user@example.com", "role_slug": "manager" }

# 3. Add permissions to role (TOO LATE!)
POST /admin/set-role-pages { "role_slug": "manager", "permissions": [...] }

# ❌ User still has 0 permissions - need manual fix!
```

---

## Common Errors

### Error: "Role does not exist"
**Cause:** Typo in `role_slug` or role not created yet.

**Fix:**
```bash
# List all roles
GET /admin/roles

# Create the role
POST /admin/create-role { "slug": "manager", "label": "Manager" }
```

### Error: "Invalid page_slug"
**Cause:** Page doesn't exist in `pages` table.

**Fix:** Check available pages:
```sql
SELECT slug, label FROM pages ORDER BY slug;
```

Available pages:
- dashboard
- machines
- products
- inventory
- sales
- finance
- support
- marketing
- users
- settings

### Warning: "Role created but failed to assign permissions"
**Cause:** Database constraint violation or RLS policy blocked the operation.

**Fix:** Check logs and manually insert permissions using SQL above.

---

## Diagnostic Commands

### Check Database State
```sql
-- 1. Check if user exists
SELECT id, email FROM auth.users WHERE email = 'user@example.com';

-- 2. Check user's role
SELECT u.email, r.slug as role
FROM auth.users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
WHERE u.email = 'user@example.com';

-- 3. Check role's permissions
SELECT r.slug, p.slug, rpp.perms_mask
FROM roles r
JOIN role_page_perms rpp ON rpp.role_id = r.id
JOIN pages p ON p.id = rpp.page_id
WHERE r.slug = 'manager';

-- 4. Check user's actual permissions
SELECT u.email, p.slug, upp.perms_mask
FROM auth.users u
JOIN user_page_perms upp ON upp.user_id = u.id
JOIN pages p ON p.id = upp.page_id
WHERE u.email = 'user@example.com';

-- 5. Check effective permissions (what user actually gets)
SELECT * FROM user_effective_page_perms
WHERE user_id = 'USER_UUID';
```

### Use API Diagnostic Endpoint
```bash
GET /admin/check-trigger
Authorization: Bearer ADMIN_TOKEN
```

### Check Enhanced Create User Response
When you create a user, the response now includes debug info:
```json
{
  "user": { ... },
  "role_assigned": true,
  "role_slug": "manager",
  "role_permissions_count": 5,        // How many perms the role has
  "user_permissions_granted": 5,      // How many perms user got
  "debug": {
    "role_had_permissions": true,     // Role has perms defined
    "trigger_granted_permissions": true,  // Trigger copied them
    "trigger_worked": true              // Counts match = success
  }
}
```

If `trigger_worked: false`, the trigger failed!

---

## Need More Help?

1. Check [STREAMLINED_WORKFLOW.md](./STREAMLINED_WORKFLOW.md) for correct usage
2. Check [ROLE_BASED_PERMISSIONS.md](./ROLE_BASED_PERMISSIONS.md) for system details
3. Check server logs for errors
4. Run diagnostic queries above
5. Use `/admin/check-trigger` endpoint
