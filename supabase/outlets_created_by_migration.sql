-- ============================================================
-- Outlets — created_by tracking
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER routes_redesign_migration.sql has already been applied)
-- ============================================================
-- routes_redesign_migration.sql dropped outlets.assigned_salesperson_id
-- (a shop now belongs to a Route, not a person). That's correct for
-- "who currently owns this shop", but it also removed the only way to
-- know WHO ADDED a given outlet — which the Admin "New Dealer Added"
-- notification needs.
--
-- This adds a simple created_by column, auto-stamped with whoever is
-- logged in at insert time (admin or salesperson), so that history is
-- never lost again even as route ownership changes later.
-- ============================================================

alter table outlets add column if not exists created_by uuid references profiles(id);

-- Backfill: best-effort only, nothing to backfill from (the old
-- assigned_salesperson_id is already gone) — new rows will populate
-- correctly going forward.

create or replace function public.set_outlet_created_by()
returns trigger as $$
begin
  if new.created_by is null then
    new.created_by = auth.uid();
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists set_outlet_created_by_trigger on outlets;
create trigger set_outlet_created_by_trigger
  before insert on outlets
  for each row execute procedure public.set_outlet_created_by();
