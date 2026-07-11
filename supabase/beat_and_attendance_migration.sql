-- ============================================================
-- Beat Plans + Attendance — supporting migration for the Salesman
-- Home Dashboard
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql and admin_migration.sql — it uses is_admin())
-- ============================================================

-- 1. BEAT PLANS — the "Assigned Area" banner on the Home dashboard.
--    One row per salesperson per day. In the full product this would be
--    created by an Admin the day before (e.g. from an Admin "Assign Beat"
--    screen — not built in this MVP, see README); for now, insert rows
--    directly via SQL (see README "Demo data" section) to populate it.
create table if not exists beat_plans (
  id uuid default gen_random_uuid() primary key,
  salesperson_id uuid references profiles(id) not null,
  plan_date date not null,
  zone_name text not null,
  coverage_km numeric(5,1),
  created_at timestamp with time zone default now(),
  unique (salesperson_id, plan_date)
);

alter table beat_plans enable row level security;

create policy "Salesperson sees own beat plans" on beat_plans
  for select using (auth.uid() = salesperson_id);

create policy "Admin can view all beat plans" on beat_plans
  for select using (is_admin());

create policy "Admin can insert beat plans" on beat_plans
  for insert with check (is_admin());

create policy "Admin can update beat plans" on beat_plans
  for update using (is_admin());

-- 2. ATTENDANCE — backs the "Attendance" card + "Start Shift" quick action.
create table if not exists attendance (
  id uuid default gen_random_uuid() primary key,
  salesperson_id uuid references profiles(id) not null,
  attendance_date date not null,
  status text default 'present', -- present | absent | on_leave
  check_in_time timestamp with time zone,
  created_at timestamp with time zone default now(),
  unique (salesperson_id, attendance_date)
);

alter table attendance enable row level security;

create policy "Salesperson sees own attendance" on attendance
  for select using (auth.uid() = salesperson_id);

create policy "Salesperson can insert own attendance" on attendance
  for insert with check (auth.uid() = salesperson_id);

create policy "Salesperson can update own attendance" on attendance
  for update using (auth.uid() = salesperson_id);

create policy "Admin can view all attendance" on attendance
  for select using (is_admin());

-- ============================================================
-- DEMO DATA — run after you have a salesperson's user id (see README
-- Step 3). Replace PASTE_USER_ID_HERE and adjust the date/zone/coverage.
-- ============================================================
-- insert into beat_plans (salesperson_id, plan_date, zone_name, coverage_km)
-- values ('PASTE_USER_ID_HERE', current_date, 'South Delhi Zone-3', 8.2)
-- on conflict (salesperson_id, plan_date) do update
--   set zone_name = excluded.zone_name, coverage_km = excluded.coverage_km;
