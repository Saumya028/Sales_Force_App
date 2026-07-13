-- ============================================================
-- Route Outlets — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql, admin_migration.sql, and
-- beat_and_attendance_migration.sql have already been applied)
-- ============================================================
-- Until now, `beat_plans` only recorded a zone name + coverage distance
-- for a salesperson's day — it wasn't tied to specific shops. This adds
-- a join table so an Admin can pick exactly which dealers belong to a
-- given route, and the salesperson's "Territory" map only shows those.
-- ============================================================

create table if not exists route_outlets (
  id uuid default gen_random_uuid() primary key,
  beat_plan_id uuid references beat_plans(id) on delete cascade not null,
  outlet_id uuid references outlets(id) on delete cascade not null,
  created_at timestamp with time zone default now(),
  unique (beat_plan_id, outlet_id)
);

alter table route_outlets enable row level security;

-- Salesperson can see the shop list for their own route(s)
create policy "Salesperson sees own route outlets" on route_outlets
  for select using (
    exists (
      select 1 from beat_plans bp
      where bp.id = route_outlets.beat_plan_id
        and bp.salesperson_id = auth.uid()
    )
  );

-- Admin manages route <-> outlet assignments
create policy "Admin can view all route outlets" on route_outlets
  for select using (is_admin());

create policy "Admin can insert route outlets" on route_outlets
  for insert with check (is_admin());

create policy "Admin can delete route outlets" on route_outlets
  for delete using (is_admin());
