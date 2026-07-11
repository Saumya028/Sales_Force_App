-- ============================================================
-- Admin — Manage Salesmen — supporting migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql, admin_migration.sql, beat_and_attendance_migration.sql
--  and leave_and_checkout_migration.sql have already been applied)
-- ============================================================
-- Backs the new Admin Dashboard's "Salesmen" management screen:
--   - Add Salesman  (uses existing AuthService.signUp — no schema change)
--   - Remove Salesman (soft delete — see below; a Supabase client app has
--     no service-role key, so it can't call auth.admin.deleteUser. Instead
--     we flag the profile 'inactive': they disappear from the active
--     roster/counters and are signed out + blocked from signing back in
--     by AuthGate, without breaking the orders/outlets/attendance history
--     that reference their profile id.)
--   - Approve/Reject Leave (uses existing leave_requests admin policies)
--   - Assign Route (uses existing beat_plans admin policies)
-- ============================================================

-- 1. Soft-delete flag on profiles.
alter table profiles add column if not exists status text default 'active';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_status_check'
  ) then
    alter table profiles add constraint profiles_status_check
      check (status in ('active', 'inactive'));
  end if;
end $$;

-- 2. Admins need to be able to update OTHER people's profiles (to set
--    status = 'inactive'/'active'). The existing "Users can update own
--    profile" policy only covers auth.uid() = id.
create policy "Admin can update all profiles" on profiles
  for update using (is_admin());

-- 3. Optional rejection note on a leave request (mirrors orders.admin_remarks).
--    Updating leave_requests as an admin is already allowed by the
--    "Admin can update all leave requests" policy from
--    leave_and_checkout_migration.sql — no new policy needed here.
alter table leave_requests add column if not exists admin_remarks text;
