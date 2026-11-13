-- Add retailer and purchase_price columns to products table
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS retailer text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS purchase_price numeric(10,2);

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';

