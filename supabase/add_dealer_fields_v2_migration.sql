-- ============================================================
-- Add New Dealer — Migration v2
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql, add_outlet_migration.sql, and
-- add_dealer_fields_migration.sql have already been applied)
-- ============================================================
-- Adds the extra fields the manager asked for on the "Add New Dealer"
-- screen: multiple owner names, manager/accountant details, office
-- telephone/email, website/Instagram, working hours, weekly off,
-- dealer category, and an owner photo + open-ended extra photos.
--
-- Note on `business_type` (retailer/wholesaler/distributor, added in
-- add_dealer_fields_migration.sql): it is left in place for old rows
-- and is NOT dropped, but the app no longer shows it on the Add Dealer
-- screen — it's been replaced there by the broader `dealer_category`
-- field below (e.g. General Store, Stationery, Medical Store).
-- ============================================================

alter table outlets
  add column if not exists owner_names text[],
  add column if not exists dealer_category text,
  add column if not exists manager_name text,
  add column if not exists manager_phone text,
  add column if not exists office_telephone text,
  add column if not exists office_email text,
  add column if not exists website text,
  add column if not exists working_hours_from text,
  add column if not exists working_hours_to text,
  add column if not exists weekly_off text,
  add column if not exists owner_photo_url text,
  add column if not exists extra_photo_urls text[];

-- Backfill owner_names for any existing rows from the old single-name
-- column, so nothing already in the DB appears to have no owner.
update outlets
set owner_names = array[contact_person]
where owner_names is null
  and contact_person is not null
  and contact_person <> '';
