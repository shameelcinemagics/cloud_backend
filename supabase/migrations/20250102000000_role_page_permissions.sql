-- Migration: Role-Based Page Permissions
-- Created: 2025-01-02
-- Description: Adds role_page_perms table and updates effective permissions view

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250102000000', 'Role-based page permissions system')
ON CONFLICT (version) DO NOTHING;

-- ===== Role Page Permissions Table =====
-- Defines default permissions for each role on each page
CREATE TABLE IF NOT EXISTS public.role_page_perms (
  role_id BIGINT REFERENCES public.roles(id) ON DELETE CASCADE,
  page_id BIGINT REFERENCES public.pages(id) ON DELETE CASCADE,
  perms_mask INT NOT NULL CHECK (perms_mask >= 0 AND perms_mask <= 15),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (role_id, page_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_role_page_perms_role_id ON public.role_page_perms(role_id);
CREATE INDEX IF NOT EXISTS idx_role_page_perms_page_id ON public.role_page_perms(page_id);

-- Enable RLS
ALTER TABLE public.role_page_perms ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Authenticated users can read role permissions
DROP POLICY IF EXISTS "Authenticated users can read role permissions" ON public.role_page_perms;
CREATE POLICY "Authenticated users can read role permissions"
  ON public.role_page_perms FOR SELECT
  TO authenticated
  USING (true);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_role_page_perms_updated_at ON public.role_page_perms;
CREATE TRIGGER update_role_page_perms_updated_at
  BEFORE UPDATE ON public.role_page_perms
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Add comment
COMMENT ON TABLE public.role_page_perms IS 'Default page permissions for each role (bitmask: C:1, R:2, U:4, D:8)';

-- ===== Update Effective Permissions View =====
-- This view now considers:
-- 1. Admin role gets full CRUD (15) on all pages
-- 2. Other roles get their role_page_perms
-- 3. Individual user_page_perms override role permissions (if set)
CREATE OR REPLACE VIEW public.user_effective_page_perms AS
WITH user_roles_with_perms AS (
  SELECT
    ur.user_id,
    r.slug AS role_slug,
    rpp.page_id,
    rpp.perms_mask AS role_perms
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  LEFT JOIN public.role_page_perms rpp ON rpp.role_id = r.id
),
aggregated_role_perms AS (
  SELECT
    user_id,
    page_id,
    -- Use bitwise OR to combine permissions from multiple roles
    BIT_OR(role_perms) AS combined_role_perms,
    -- Check if user has admin role
    BOOL_OR(role_slug = 'admin') AS is_admin
  FROM user_roles_with_perms
  GROUP BY user_id, page_id
)
SELECT
  u.id AS user_id,
  p.slug AS page_slug,
  p.id AS page_id,
  CASE
    -- Admin users get full CRUD (15) on all pages
    WHEN arp.is_admin THEN 15
    -- User-specific permissions override role permissions
    WHEN upp.perms_mask IS NOT NULL THEN upp.perms_mask
    -- Role-based permissions
    WHEN arp.combined_role_perms IS NOT NULL THEN arp.combined_role_perms
    -- No permissions
    ELSE 0
  END AS perms_mask
FROM auth.users u
CROSS JOIN public.pages p
LEFT JOIN aggregated_role_perms arp
  ON arp.user_id = u.id AND arp.page_id = p.id
LEFT JOIN public.user_page_perms upp
  ON upp.user_id = u.id AND upp.page_id = p.id;

-- ===== Insert Default Role Permissions =====
-- Give admin role full CRUD on all pages (this is now redundant due to admin check, but good for documentation)
INSERT INTO public.role_page_perms (role_id, page_id, perms_mask)
SELECT
  r.id AS role_id,
  p.id AS page_id,
  15 AS perms_mask  -- Full CRUD
FROM public.roles r
CROSS JOIN public.pages p
WHERE r.slug = 'admin'
ON CONFLICT (role_id, page_id) DO NOTHING;

-- ===== Function to Copy Role Permissions to New User =====
-- This function automatically grants role-based permissions when a user is assigned a role
CREATE OR REPLACE FUNCTION public.grant_role_permissions_to_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert role's page permissions for the new user
  -- Only if they don't have explicit user permissions already
  INSERT INTO public.user_page_perms (user_id, page_id, perms_mask)
  SELECT
    NEW.user_id,
    rpp.page_id,
    rpp.perms_mask
  FROM public.role_page_perms rpp
  WHERE rpp.role_id = NEW.role_id
  ON CONFLICT (user_id, page_id) DO NOTHING;  -- Don't override existing user permissions

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: When a user is assigned a role, grant them the role's permissions
DROP TRIGGER IF EXISTS trigger_grant_role_permissions ON public.user_roles;
CREATE TRIGGER trigger_grant_role_permissions
  AFTER INSERT ON public.user_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.grant_role_permissions_to_user();

-- Grant execute on function
GRANT EXECUTE ON FUNCTION public.grant_role_permissions_to_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_role_permissions_to_user() TO service_role;

-- ===== Rollback Instructions =====
-- To rollback this migration:
-- DROP TRIGGER IF EXISTS trigger_grant_role_permissions ON public.user_roles;
-- DROP FUNCTION IF EXISTS public.grant_role_permissions_to_user();
-- DROP VIEW IF EXISTS public.user_effective_page_perms;
-- DROP TABLE IF EXISTS public.role_page_perms CASCADE;
-- DELETE FROM public.schema_migrations WHERE version = '20250102000000';
-- Then re-create the old view from 001_core.sql
