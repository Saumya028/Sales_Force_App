-- ============================================================
-- Admin Approve/Reject — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql has already been applied)
-- ============================================================

-- 1. New column to store the admin's rejection reason
--    (kept separate from `remarks`, which is the salesperson's own
--    visit note for No Order / Follow-up)
alter table orders add column if not exists admin_remarks text;

-- 2. Helper function to check if the current user is an admin.
--    Using `security definer` avoids infinite-recursion issues that
--    happen when a policy on `profiles` queries `profiles` directly.
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;

-- 3. Admin RLS policies (these ADD to the existing salesperson policies —
--    Postgres combines multiple permissive policies with OR, so
--    salespeople keep seeing only their own data, while admins see all)

create policy "Admin can view all orders" on orders
  for select using (is_admin());

create policy "Admin can update all orders" on orders
  for update using (is_admin());

create policy "Admin can view all order items" on order_items
  for select using (is_admin());

create policy "Admin can view all outlets" on outlets
  for select using (is_admin());

create policy "Admin can view all profiles" on profiles
  for select using (is_admin());

-- ============================================================
-- 4. Make your demo user an Admin
--    Run this separately, replacing the email with your admin's:
-- ============================================================
-- update profiles set role = 'admin'
-- where id = (select id from auth.users where email = 'admin@yourcompany.com');
