-- ============================================================
-- Add New Dealer — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql and add_outlet_migration.sql have already been
-- applied)
-- ============================================================
-- Adds the extra fields shown on the "Add New Dealer" screen: GST
-- number, business type, shop front / business card photos, and
-- auto-captured GPS coordinates. (Owner Name and Mobile Number reuse the
-- existing contact_person / contact_number columns, so no change needed
-- for those.)
-- ============================================================

alter table outlets
  add column if not exists gst_number text,
  add column if not exists business_type text
    check (business_type in ('retailer', 'wholesaler', 'distributor')),
  add column if not exists shop_front_photo_url text,
  add column if not exists business_card_photo_url text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

-- ============================================================
-- Storage bucket for dealer photos (Shop Front / Business Card)
-- ============================================================
-- Public bucket so photo URLs can be displayed directly in the app
-- without needing signed URLs. Uploads are still restricted to
-- authenticated users, into a folder named after their own user id.

insert into storage.buckets (id, name, public)
values ('dealer-photos', 'dealer-photos', true)
on conflict (id) do nothing;

create policy "Authenticated users can upload dealer photos"
  on storage.objects for insert
  with check (
    bucket_id = 'dealer-photos'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Anyone can view dealer photos"
  on storage.objects for select
  using (bucket_id = 'dealer-photos');

create policy "Users can update their own dealer photos"
  on storage.objects for update
  using (
    bucket_id = 'dealer-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
