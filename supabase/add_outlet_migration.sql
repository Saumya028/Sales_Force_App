-- ============================================================
-- Add New Shop — Migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql has already been applied)
-- ============================================================
-- Lets a salesperson create a NEW outlet themselves (e.g. when they
-- visit a shop that isn't in the system yet) instead of only being able
-- to view outlets an admin pre-assigned to them.
-- ============================================================

-- 1. Allow a logged-in salesperson to insert an outlet, as long as they
--    assign it to themselves (assigned_salesperson_id = their own uid).
--    This mirrors the existing "insert own orders" pattern.
create policy "Salesperson can insert own outlets" on outlets
  for insert with check (auth.uid() = assigned_salesperson_id);
