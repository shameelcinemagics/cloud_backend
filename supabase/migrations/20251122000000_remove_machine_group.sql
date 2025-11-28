-- Migration: Remove machine_group column from delivery_routes
-- Created: 2025-11-22
-- Description: Removes the machine_group field from delivery_routes table as it's no longer needed

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20251122000000', 'Remove machine_group column from delivery_routes')
ON CONFLICT (version) DO NOTHING;

-- Drop the machine_group column
ALTER TABLE public.delivery_routes
DROP COLUMN IF EXISTS machine_group;
