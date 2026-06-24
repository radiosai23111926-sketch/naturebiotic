-- SQL MIGRATION: ADD PLACE OF SUPPLY TO FARMERS
-- Execute this in the Supabase SQL Editor

ALTER TABLE public.farmers ADD COLUMN IF NOT EXISTS place_of_supply TEXT;
