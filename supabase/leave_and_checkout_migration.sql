-- ============================================================
-- Attendance Check-Out + Leave Requests — supporting migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER beat_and_attendance_migration.sql)
-- ============================================================

-- 1. Add check-out time to the existing attendance table, so we can
--    compute a real "hours worked" figure (End Shift sets this).
alter table attendance add column if not exists check_out_time timestamp with time zone;

-- 2. LEAVE REQUESTS — backs the "Apply Leave" screen.
create table if not exists leave_requests (
  id uuid default gen_random_uuid() primary key,
  salesperson_id uuid references profiles(id) not null,
  leave_type text not null,      -- casual | sick | emergency | earned
  start_date date not null,
  end_date date not null,
  reason text,
  attachment_path text,          -- storage object path in 'leave-attachments' bucket, if any
  status text default 'pending', -- pending | approved | rejected
  created_at timestamp with time zone default now(),
  check (end_date >= start_date)
);

alter table leave_requests enable row level security;

create policy "Salesperson sees own leave requests" on leave_requests
  for select using (auth.uid() = salesperson_id);

create policy "Salesperson can submit own leave requests" on leave_requests
  for insert with check (auth.uid() = salesperson_id);

create policy "Admin can view all leave requests" on leave_requests
  for select using (is_admin());

create policy "Admin can update all leave requests" on leave_requests
  for update using (is_admin());

-- 3. STORAGE — a private bucket for optional leave-request attachments
--    (medical certificates, etc). Each user can only read/write inside
--    their own folder: leave-attachments/{their_user_id}/{filename}.
insert into storage.buckets (id, name, public)
values ('leave-attachments', 'leave-attachments', false)
on conflict (id) do nothing;

create policy "Users upload their own leave attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users read their own leave attachments"
  on storage.objects for select
  using (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Admin reads all leave attachments"
  on storage.objects for select
  using (bucket_id = 'leave-attachments' and is_admin());

-- ============================================================
-- DEMO: approving/rejecting a leave request today happens manually
-- via SQL (no Admin UI for this yet — see README). Example:
-- ============================================================
-- update leave_requests set status = 'approved' where id = 'PASTE_LEAVE_REQUEST_ID';
