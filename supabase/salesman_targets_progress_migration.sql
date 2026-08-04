-- ============================================================
-- Salesman "My Targets" — supporting migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER sales_targets_migration.sql and
--  outlets_created_by_migration.sql have already been applied)
-- ============================================================
-- "New Dealer" targets need a salesperson to count outlets THEY
-- personally added this month. The existing outlets SELECT policy
-- ("Salesperson sees own route outlets") only covers shops on their
-- CURRENT route — which drops out if their route changes mid-month.
-- This adds a second, additive policy keyed off created_by instead,
-- so their own progress numbers stay correct regardless of route
-- reassignment.
-- ============================================================

create policy "Salesperson can view own created outlets" on outlets
  for select using (auth.uid() = created_by);
