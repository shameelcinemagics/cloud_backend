-- Script: Fix User Permissions
-- Purpose: Manually grant role permissions to users who didn't get them via trigger
-- Use Case: When users were created before role had permissions assigned

-- ===== INSTRUCTIONS =====
-- 1. Replace 'YOUR_ROLE_SLUG' with the actual role slug (e.g., 'manager')
-- 2. Run this script in Supabase SQL Editor
-- 3. This will grant role permissions to ALL users with that role

-- ===== STEP 1: Check Current State =====

-- See which users have the role
SELECT
  u.id as user_id,
  u.email,
  r.slug as role_slug,
  COUNT(upp.page_id) as current_permissions_count
FROM auth.users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
LEFT JOIN user_page_perms upp ON upp.user_id = u.id
WHERE r.slug = 'YOUR_ROLE_SLUG'  -- ⚠️ REPLACE THIS
GROUP BY u.id, u.email, r.slug
ORDER BY u.email;

-- Check what permissions the role has
SELECT
  r.slug as role_slug,
  p.slug as page_slug,
  p.label as page_label,
  rpp.perms_mask,
  CASE
    WHEN rpp.perms_mask = 2 THEN 'view'
    WHEN rpp.perms_mask = 15 THEN 'admin'
    ELSE 'custom'
  END as level
FROM roles r
JOIN role_page_perms rpp ON rpp.role_id = r.id
JOIN pages p ON p.id = rpp.page_id
WHERE r.slug = 'YOUR_ROLE_SLUG'  -- ⚠️ REPLACE THIS
ORDER BY p.slug;

-- ===== STEP 2: Grant Permissions to All Users with Role =====

-- This will copy role permissions to ALL users who have this role
-- Safe to run multiple times (ON CONFLICT DO NOTHING prevents duplicates)
INSERT INTO user_page_perms (user_id, page_id, perms_mask)
SELECT
  ur.user_id,
  rpp.page_id,
  rpp.perms_mask
FROM user_roles ur
JOIN role_page_perms rpp ON rpp.role_id = ur.role_id
JOIN roles r ON r.id = ur.role_id
WHERE r.slug = 'YOUR_ROLE_SLUG'  -- ⚠️ REPLACE THIS
ON CONFLICT (user_id, page_id) DO NOTHING;

-- ===== STEP 3: Verify Permissions Were Granted =====

-- Check users now have permissions
SELECT
  u.id as user_id,
  u.email,
  r.slug as role_slug,
  COUNT(upp.page_id) as permissions_count
FROM auth.users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
LEFT JOIN user_page_perms upp ON upp.user_id = u.id
WHERE r.slug = 'YOUR_ROLE_SLUG'  -- ⚠️ REPLACE THIS
GROUP BY u.id, u.email, r.slug
ORDER BY u.email;

-- Check what permissions a specific user has
SELECT
  u.email,
  p.slug as page_slug,
  p.label as page_label,
  upp.perms_mask,
  CASE
    WHEN upp.perms_mask = 2 THEN 'view'
    WHEN upp.perms_mask = 15 THEN 'admin'
    ELSE 'custom'
  END as level
FROM auth.users u
JOIN user_page_perms upp ON upp.user_id = u.id
JOIN pages p ON p.id = upp.page_id
WHERE u.email = 'user@example.com'  -- ⚠️ REPLACE THIS
ORDER BY p.slug;

-- ===== ALTERNATIVE: Fix Single User =====

-- If you only want to fix one user, use this instead:
/*
INSERT INTO user_page_perms (user_id, page_id, perms_mask)
SELECT
  'USER_UUID_HERE',  -- ⚠️ REPLACE with actual user UUID
  rpp.page_id,
  rpp.perms_mask
FROM role_page_perms rpp
WHERE rpp.role_id = (SELECT id FROM roles WHERE slug = 'YOUR_ROLE_SLUG')
ON CONFLICT (user_id, page_id) DO NOTHING;
*/

-- ===== Check Effective Permissions =====

-- This view shows what the user will actually get (includes admin role logic)
SELECT
  u.email,
  uep.page_slug,
  uep.perms_mask,
  CASE
    WHEN uep.perms_mask = 2 THEN 'view'
    WHEN uep.perms_mask = 15 THEN 'admin'
    WHEN uep.perms_mask = 0 THEN 'none'
    ELSE 'custom'
  END as level
FROM auth.users u
JOIN user_effective_page_perms uep ON uep.user_id = u.id
WHERE u.email = 'user@example.com'  -- ⚠️ REPLACE THIS
ORDER BY uep.page_slug;

-- ===== DONE! =====
-- Users should now have their role's permissions.
-- They can verify by calling: GET /pages/my-pages
