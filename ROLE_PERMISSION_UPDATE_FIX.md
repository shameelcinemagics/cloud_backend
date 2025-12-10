# Role Permission Update Fix

## Issues Fixed

### 1. Frontend API Call Error
**Problem:** The frontend was calling `adminApi.setRolePages()` with two separate parameters instead of a single object.

**Error:** 
```
SyntaxError: Unexpected token '"', ""test"" is not valid JSON
```

**Location:** `Vendit_Cloud/src/pages/Users.tsx:353-356`

**Fix:**
Changed from:
```typescript
await adminApi.setRolePages(
  editingRole.slug,
  validPermissions.length > 0 ? validPermissions : []
);
```

To:
```typescript
await adminApi.setRolePages({
  role_slug: editingRole.slug,
  permissions: validPermissions.length > 0 ? validPermissions : []
});
```

### 2. Backend Empty Permissions Validation
**Problem:** Backend was rejecting empty permission arrays, preventing users from removing all permissions from a role.

**Location:** `Cloud_backend/cloud_backend/src/routes/admin.ts:360`

**Fix:**
- Changed validation from `permissions.length === 0` (error) to allowing empty arrays
- Added special handling for empty arrays to delete all permissions

### 3. Backend Permission Update Logic
**Problem:** When updating role permissions, old permissions that weren't in the new list were NOT being deleted. For example:
- Role had: `dashboard: view`, `sales: admin`
- User updates to: `dashboard: view` only
- Result: Role still had BOTH `dashboard: view` AND `sales: admin`

**Location:** `Cloud_backend/cloud_backend/src/routes/admin.ts:420-467`

**Fix:**
Changed from upsert logic (which only added/updated) to:
1. **Step 1:** Delete ALL existing permissions for the role
2. **Step 2:** Insert only the new permissions (excluding 'none')

This ensures the role has EXACTLY the permissions specified, nothing more, nothing less.

## Updated Logic Flow

### Backend `/admin/set-role-pages` Endpoint

```typescript
// Validate input
if (!isNonEmptyString(role_slug)) return error;
if (!Array.isArray(permissions)) return error;

// Get role
const role = await getRoleBySlug(role_slug);

// Handle empty array - delete all permissions
if (permissions.length === 0) {
  await deleteAllPermissions(role.id);
  return success;
}

// Validate permissions array
validatePermissions(permissions);

// Get page IDs
const pages = await getPagesBySlugs(pageSlugs);

// Step 1: Delete ALL existing permissions
await deleteAllPermissions(role.id);

// Step 2: Insert only new permissions (skip 'none')
const recordsToInsert = permissions
  .filter(p => p.level !== 'none')
  .map(p => ({
    role_id: role.id,
    page_id: getPageId(p.page_slug),
    perms_mask: p.level === 'view' ? 2 : 15
  }));

await insertPermissions(recordsToInsert);

return success;
```

## Testing

To test the fixes:

1. **Create a test role** with multiple permissions:
   - Dashboard: View
   - Sales: Admin
   - Products: Admin

2. **Edit the role** and change to only:
   - Dashboard: View

3. **Save** and verify that:
   - Only "Dashboard: View" remains
   - "Sales: Admin" and "Products: Admin" are removed

4. **Edit again** and remove all permissions

5. **Save** and verify that:
   - No permissions remain for the role

## Files Modified

1. `Vendit_Cloud/src/pages/Users.tsx` (line 353)
   - Fixed API call to send proper object structure

2. `Cloud_backend/cloud_backend/src/routes/admin.ts` (lines 356-467)
   - Allowed empty permission arrays
   - Changed from upsert to delete-all-then-insert logic
