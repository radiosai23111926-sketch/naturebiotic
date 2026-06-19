-- SQL MIGRATION: BILLING SYSTEM
-- Run this in your Supabase SQL Editor

-- 1. Add tax_percentage column to dropdown_options table
ALTER TABLE public.dropdown_options 
ADD COLUMN IF NOT EXISTS tax_percentage DOUBLE PRECISION DEFAULT 0.0;

-- 2. Create bills table
CREATE TABLE IF NOT EXISTS public.bills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
  executive_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  challan_no TEXT NOT NULL,
  challan_date TIMESTAMPTZ NOT NULL,
  items JSONB NOT NULL, -- list of items (name, unit, quantity, offer_price)
  discount_type TEXT NOT NULL DEFAULT 'none', -- 'percentage', 'flat', 'none'
  discount_value DOUBLE PRECISION DEFAULT 0.0,
  total_discount DOUBLE PRECISION DEFAULT 0.0,
  total_taxable_amount DOUBLE PRECISION DEFAULT 0.0,
  total_tax_amount DOUBLE PRECISION DEFAULT 0.0,
  grand_total DOUBLE PRECISION DEFAULT 0.0,
  status TEXT NOT NULL DEFAULT 'PENDING_BILLING', -- 'PENDING_BILLING', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'BILLED'
  admin_notes TEXT,
  place_of_supply TEXT,
  customer_gstin TEXT,
  customer_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Add columns if table already exists
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS place_of_supply TEXT;
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS customer_gstin TEXT;
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS customer_name TEXT;

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS Policies
CREATE POLICY "Allow public read access to bills" 
ON public.bills 
FOR SELECT 
USING (true);

CREATE POLICY "Allow authenticated full access to bills" 
ON public.bills 
FOR ALL 
USING (auth.role() = 'authenticated');
