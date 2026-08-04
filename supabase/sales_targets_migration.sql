-- ============================================================
-- Admin — Target Management — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql and admin_migration.sql — needs is_admin() —
--  have already been applied. Also run AFTER outlets_created_by_migration.sql
--  if you want "New Dealer" targets to have progress tracking.)
-- ============================================================
-- Backs the new Admin "Target Management" screen:
--   - Assign Target (Value / Quantity / New Dealer / Product) to a
--     salesperson for a given month
--   - Team Performance overview + per-salesman progress, computed live
--     from orders/order_items/outlets (nothing here is a cached number)
-- ============================================================

create table if not exists sales_targets (
  id uuid default gen_random_uuid() primary key,
  salesperson_id uuid references profiles(id) on delete cascade not null,
  target_type text not null, -- value | quantity | new_dealer | product
  product_id uuid references products(id),
  goal_value numeric(12,2) not null,
  period text not null, -- 'YYYY-MM', e.g. '2026-08'
  priority text default 'medium',
  manager_note text,
  created_by uuid references profiles(id),
  created_at timestamp with time zone default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sales_targets_type_check'
  ) then
    alter table sales_targets add constraint sales_targets_type_check
      check (target_type in ('value', 'quantity', 'new_dealer', 'product'));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'sales_targets_priority_check'
  ) then
    alter table sales_targets add constraint sales_targets_priority_check
      check (priority in ('low', 'medium', 'high'));
  end if;
end $$;

create index if not exists sales_targets_period_idx on sales_targets(period);
create index if not exists sales_targets_salesperson_idx on sales_targets(salesperson_id);

alter table sales_targets enable row level security;

-- Admin: full CRUD on every target.
create policy "Admin can view all targets" on sales_targets
  for select using (is_admin());
create policy "Admin can insert targets" on sales_targets
  for insert with check (is_admin());
create policy "Admin can update targets" on sales_targets
  for update using (is_admin());
create policy "Admin can delete targets" on sales_targets
  for delete using (is_admin());

-- Salesperson: read-only view of their own targets (for a future
-- "My Targets" screen on their side of the app).
create policy "Salesperson can view own targets" on sales_targets
  for select using (auth.uid() = salesperson_id);
