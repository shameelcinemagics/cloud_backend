-- Migration: Product Nutrition Fields
-- Created: 2025-01-22
-- Description: Adds nutrition information columns to the products table

-- Record this migration
INSERT INTO public.schema_migrations (version, description)
VALUES ('20250122000000', 'Product nutrition fields - ingredients, health_rating, calories, fat, carbs, protein, sodium')
ON CONFLICT (version) DO NOTHING;

-- ===== Add Nutrition Columns to Products Table =====

-- Ingredients field for listing product ingredients
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS ingredients TEXT;

-- Health rating (1-3 scale: 1=Low, 2=Medium, 3=High)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS health_rating INTEGER CHECK (health_rating IS NULL OR (health_rating >= 1 AND health_rating <= 3));

-- Calories (in kcal)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS calories NUMERIC(8, 2);

-- Fat content (in grams)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS fat NUMERIC(8, 2);

-- Carbohydrates content (in grams)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS carbs NUMERIC(8, 2);

-- Protein content (in grams)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS protein NUMERIC(8, 2);

-- Sodium content (in milligrams)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS sodium NUMERIC(8, 2);

-- ===== Add Comments for Documentation =====
COMMENT ON COLUMN public.products.ingredients IS 'List of product ingredients';
COMMENT ON COLUMN public.products.health_rating IS 'Health rating scale: 1=Low, 2=Medium, 3=High';
COMMENT ON COLUMN public.products.calories IS 'Calorie content in kcal';
COMMENT ON COLUMN public.products.fat IS 'Fat content in grams';
COMMENT ON COLUMN public.products.carbs IS 'Carbohydrate content in grams';
COMMENT ON COLUMN public.products.protein IS 'Protein content in grams';
COMMENT ON COLUMN public.products.sodium IS 'Sodium content in milligrams';
