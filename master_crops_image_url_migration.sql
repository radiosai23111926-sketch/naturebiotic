-- 1. Add the image_url column to the master_crops table
ALTER TABLE public.master_crops ADD COLUMN IF NOT EXISTS image_url text;

-- 2. Verify that the table is configured correctly for dynamic crop image displays
COMMENT ON COLUMN public.master_crops.image_url IS 'URL of the dynamic high-fidelity crop representation image uploaded by admin';

-- 3. Ensure the storage bucket exists and is public for crop image retrieval
-- Supabase automatically manages bucket creation when uploading, but if you want to ensure the bucket policies are fully open:
-- (Uncomment and run these lines if you encounter storage permission errors)
/*
insert into storage.buckets (id, name, public)
values ('dropdown_covers', 'dropdown_covers', true)
on conflict (id) do nothing;

create policy "Allow public read access to dropdown covers"
  on storage.objects for select
  using ( bucket_id = 'dropdown_covers' );

create policy "Allow authenticated admin upload to dropdown covers"
  on storage.objects for insert
  with check ( bucket_id = 'dropdown_covers' );
*/
