-- Add country_code column to suppliers table
ALTER TABLE public.suppliers
ADD COLUMN IF NOT EXISTS country_code TEXT DEFAULT '+965';

-- Update existing suppliers to have Kuwait country code if they have Kuwait as country
UPDATE public.suppliers
SET country_code = '+965'
WHERE country = 'Kuwait' AND country_code IS NULL;

COMMENT ON COLUMN public.suppliers.country_code IS 'International phone country code (e.g., +965 for Kuwait)';
