-- ============================================================
-- Routes Redesign — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER all previous migrations, including route_outlets_migration.sql)
-- ============================================================
-- BEFORE: a shop (outlet) belonged permanently to one salesperson
-- (outlets.assigned_salesperson_id). "Assign Route" meant re-picking,
-- by hand, which of that salesperson's own shops counted as today's
-- route — via a per-day beat_plans row + a route_outlets join table.
--
-- AFTER: a shop belongs to a reusable Route (e.g. "Fort, Mumbai"),
-- created once by an Admin with its full shop list already on it.
-- Assigning a salesperson to a route is now just: pick the route.
-- A new shop a salesperson adds in the field is automatically stamped
-- with whichever route they're currently on.
--
-- This migration assumes it's OK to drop existing outlet-salesperson
-- assignments and the route_outlets join table (confirmed test data).
-- ============================================================

-- 1. ROUTES — a reusable named area, independent of any one day or
--    salesperson.
create table if not exists routes (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  created_at timestamp with time zone default now()
);

alter table routes enable row level security;

create policy "Authenticated users can view routes" on routes
  for select using (auth.role() = 'authenticated');

create policy "Admin can insert routes" on routes
  for insert with check (is_admin());

create policy "Admin can update routes" on routes
  for update using (is_admin());

create policy "Admin can delete routes" on routes
  for delete using (is_admin());

-- 2. OUTLETS — now belong to a route, not a person.
alter table outlets add column if not exists route_id uuid references routes(id);

-- Drop the old ownership policies before dropping the column they use.
drop policy if exists "Salesperson sees own outlets" on outlets;
drop policy if exists "Salesperson can insert own outlets" on outlets;

alter table outlets drop column if exists assigned_salesperson_id;

-- 3. PROFILES — which route each salesperson is currently covering.
--    This is the single source of truth for "who sees which shops".
alter table profiles add column if not exists current_route_id uuid references routes(id);

-- 4. New outlet RLS, keyed off the route instead of a person.
create policy "Salesperson sees own route outlets" on outlets
  for select using (
    exists (
      select 1 from profiles
      where id = auth.uid() and current_route_id = outlets.route_id
    )
  );

create policy "Salesperson can insert own route outlets" on outlets
  for insert with check (
    exists (
      select 1 from profiles
      where id = auth.uid() and current_route_id = outlets.route_id
    )
  );

-- Admins manage outlets directly too (needed for the new Routes screen —
-- previously admins could only view outlets, not create/edit them).
create policy "Admin can insert outlets" on outlets
  for insert with check (is_admin());

create policy "Admin can update outlets" on outlets
  for update using (is_admin());

-- 5. Auto-map a salesperson's self-added shop to whichever route
--    they're currently on, so they never have to pick it manually.
--    (Admin inserts are untouched — they set route_id explicitly.)
create or replace function public.set_outlet_route_id()
returns trigger as $$
begin
  if new.route_id is null and not is_admin() then
    select current_route_id into new.route_id
    from profiles where id = auth.uid();
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists set_outlet_route_id_trigger on outlets;
create trigger set_outlet_route_id_trigger
  before insert on outlets
  for each row execute procedure public.set_outlet_route_id();

-- 6. route_outlets is obsolete now that outlets carry their route
--    directly — it only ever existed to link a specific day's beat
--    plan to hand-picked shops.
drop table if exists route_outlets;

-- ============================================================
-- NOTE: beat_plans (the daily "Assigned Area" banner on the
-- salesperson Home dashboard — zone_name/coverage_km) is untouched.
-- It's a separate, date-scoped feature and isn't what plots the
-- Territory map anymore — routes/outlets.route_id is.
-- ============================================================
