-- ============================================================
-- Live Location Tracking — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql, admin_migration.sql, and
-- beat_and_attendance_migration.sql have already been applied —
-- uses is_admin() and profiles)
-- ============================================================
-- Backs the Admin "Live Tracking" screen. Each row is one GPS reading
-- sent by the salesperson's app while they're on shift (checked in,
-- app in foreground). The Admin app reads these to show each
-- salesperson's live position, speed, and today's GPS trail.
-- ============================================================

create table if not exists location_pings (
  id uuid default gen_random_uuid() primary key,
  salesperson_id uuid references profiles(id) not null,
  latitude double precision not null,
  longitude double precision not null,
  speed_kmh numeric(6,2),
  battery_level int,
  recorded_at timestamp with time zone not null default now()
);

-- Every query here is "latest/today's pings for salesperson X",
-- so this composite index carries the whole feature.
create index if not exists idx_location_pings_salesperson_recorded
  on location_pings (salesperson_id, recorded_at desc);

alter table location_pings enable row level security;

-- A salesperson can only ever insert their own pings, and can't read
-- any pings back (nothing in the salesperson-side app needs to) — this
-- is an admin-only view of the data, similar to attendance.
create policy "Salesperson can insert own location pings" on location_pings
  for insert with check (auth.uid() = salesperson_id);

create policy "Admin can view all location pings" on location_pings
  for select using (is_admin());

-- ============================================================
-- NOTE ON DATA GROWTH: tracking is foreground-only, pinging roughly
-- every 45s while the salesperson has the app open and is on shift.
-- A busy day might add a few hundred rows per salesperson. This is
-- fine for an MVP; if this table grows large, consider a periodic
-- job (e.g. Supabase cron / pg_cron) to delete rows older than a
-- retention window, e.g.:
--
--   delete from location_pings where recorded_at < now() - interval '30 days';
-- ============================================================
