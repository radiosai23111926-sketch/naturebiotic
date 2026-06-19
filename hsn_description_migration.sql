ALTER TABLE public.dropdown_options 
ADD COLUMN IF NOT EXISTS hsn_code text,
ADD COLUMN IF NOT EXISTS description text;
