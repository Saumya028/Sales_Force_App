-- ============================================================
-- Company ID Login — supporting migration
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- (Run AFTER schema.sql, admin_migration.sql, add_outlet_migration.sql)
-- ============================================================
--
-- The login screen now collects a "Company ID" (e.g. HUL-2025) instead
-- of an email address. The app maps that Company ID to a synthetic
-- Supabase Auth email under the hood (see lib/services/auth_service.dart,
-- companyIdToEmail()) — no schema change is required for sign-IN.
--
-- This migration only updates the "new user" trigger so that, if you
-- create accounts via AuthService.signUp() (which stamps role into the
-- user's metadata), the new profile row picks up that role immediately
-- instead of always defaulting to 'salesperson'. This keeps the existing
-- behavior identical for any account created another way (e.g. via the
-- Supabase Dashboard), since `role` in metadata is optional.

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    coalesce(new.raw_user_meta_data->>'role', 'salesperson')
  );
  return new;
end;
$$ language plpgsql security definer;

-- Trigger itself is unchanged (still fires on auth.users insert); we're
-- only replacing the function body above. Re-creating it here is
-- harmless/idempotent if you run this more than once.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
