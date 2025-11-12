-- Migration: User Profiles Table
-- Created: 2025-01-03
-- Description: Adds profiles table to store user profile information

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250103000000', 'User profiles table')
ON CONFLICT (version) DO NOTHING;

-- ===== User Profiles Table =====
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  phone TEXT,
  role_slug TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT profiles_email_unique UNIQUE (email)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role_slug ON public.profiles(role_slug);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read their own profile
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users can update their own profile (except role_slug)
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Service role can do everything
DROP POLICY IF EXISTS "Service role full access to profiles" ON public.profiles;
CREATE POLICY "Service role full access to profiles"
  ON public.profiles FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Add comment
COMMENT ON TABLE public.profiles IS 'User profile information for all users';
COMMENT ON COLUMN public.profiles.id IS 'User ID (references auth.users.id)';
COMMENT ON COLUMN public.profiles.email IS 'User email (synced from auth.users)';
COMMENT ON COLUMN public.profiles.full_name IS 'User full name';
COMMENT ON COLUMN public.profiles.avatar_url IS 'URL to user avatar image';
COMMENT ON COLUMN public.profiles.phone IS 'User phone number';
COMMENT ON COLUMN public.profiles.role_slug IS 'User role slug (synced from user_metadata)';

-- ===== Function to Auto-Create Profile on User Creation =====
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role_slug)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', NULL)
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Auto-create profile when user is created in auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_profile_for_new_user();

-- Grant permissions
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

-- ===== Function to Sync Profile Role from user_metadata =====
CREATE OR REPLACE FUNCTION public.sync_profile_role_from_metadata()
RETURNS TRIGGER AS $$
BEGIN
  -- Update profile role_slug when user_metadata.role changes
  UPDATE public.profiles
  SET
    role_slug = COALESCE(NEW.raw_user_meta_data->>'role', NULL),
    updated_at = NOW()
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Sync profile when user_metadata changes
DROP TRIGGER IF EXISTS on_auth_user_metadata_updated ON auth.users;
CREATE TRIGGER on_auth_user_metadata_updated
  AFTER UPDATE OF raw_user_meta_data ON auth.users
  FOR EACH ROW
  WHEN (OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data)
  EXECUTE FUNCTION public.sync_profile_role_from_metadata();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.create_profile_for_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_profile_role_from_metadata() TO service_role;

-- ===== Create Profiles for Existing Users =====
-- This will create profiles for any users that already exist
INSERT INTO public.profiles (id, email, role_slug)
SELECT
  u.id,
  u.email,
  COALESCE(u.raw_user_meta_data->>'role', NULL) as role_slug
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ===== Rollback Instructions =====
-- To rollback this migration:
-- DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- DROP TRIGGER IF EXISTS on_auth_user_metadata_updated ON auth.users;
-- DROP FUNCTION IF EXISTS public.create_profile_for_new_user();
-- DROP FUNCTION IF EXISTS public.sync_profile_role_from_metadata();
-- DROP TABLE IF EXISTS public.profiles CASCADE;
-- DELETE FROM public.schema_migrations WHERE version = '20250103000000';
