-- ============================================================
-- Notifications — supporting migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql, admin_migration.sql, and
--  leave_and_checkout_migration.sql have already been applied)
-- ============================================================
-- The Notifications feed (both Admin and Salesman) is NOT backed by a
-- new table — it's derived on the fly from tables that already exist:
-- orders, leave_requests, outlets, attendance, beat_plans. No new
-- migration is needed to add another notification type later; just
-- teach NotificationService to read a different column/table.
--
-- The one real gap: neither `orders` nor `leave_requests` recorded WHEN
-- a status changed — only `created_at` (when it was first submitted).
-- Without that, a "Your order was approved" notification would sort by
-- the original submission time, not the approval, so a 3-day-old order
-- approved 2 minutes ago wouldn't show up as new. This adds a plain
-- `updated_at`, auto-maintained by a trigger on every UPDATE.
-- ============================================================

alter table orders add column if not exists updated_at timestamp with time zone default now();
alter table leave_requests add column if not exists updated_at timestamp with time zone default now();

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_orders_updated_at on orders;
create trigger set_orders_updated_at
  before update on orders
  for each row execute procedure public.set_updated_at();

drop trigger if exists set_leave_requests_updated_at on leave_requests;
create trigger set_leave_requests_updated_at
  before update on leave_requests
  for each row execute procedure public.set_updated_at();
