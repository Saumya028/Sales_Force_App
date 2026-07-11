-- ============================================================
-- FMCG Salesman App — Supabase Schema (MVP)
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> Run
-- ============================================================

-- 1. PROFILES (extends Supabase auth.users with app-specific info)
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text,
  role text default 'salesperson',
  created_at timestamp with time zone default now()
);

-- Auto-create a profile row whenever a new user signs up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. OUTLETS (retailers a salesperson visits)
create table if not exists outlets (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  address text,
  contact_person text,
  contact_number text,
  assigned_salesperson_id uuid references profiles(id),
  created_at timestamp with time zone default now()
);

-- 3. PRODUCTS (catalog)
create table if not exists products (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  sku text,
  price numeric(10,2) not null,
  stock int default 0,
  created_at timestamp with time zone default now()
);

-- 4. ORDERS (also stores "no order" / "follow-up" visit outcomes)
create table if not exists orders (
  id uuid default gen_random_uuid() primary key,
  salesperson_id uuid references profiles(id),
  outlet_id uuid references outlets(id),
  outcome text default 'order_placed', -- order_placed | no_order | follow_up
  status text default 'pending_approval', -- pending_approval | approved | rejected | closed | follow_up_scheduled
  remarks text,
  follow_up_date date,
  total_amount numeric(10,2) default 0,
  created_at timestamp with time zone default now()
);

-- 5. ORDER ITEMS (line items per order)
create table if not exists order_items (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id),
  quantity int not null,
  price numeric(10,2) not null,
  amount numeric(10,2) not null
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- Ensures a salesperson can only see/insert their own data.
-- ============================================================

alter table profiles enable row level security;
alter table outlets enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

-- Profiles: users can read/update their own profile
create policy "Users can view own profile" on profiles
  for select using (auth.uid() = id);
create policy "Users can update own profile" on profiles
  for update using (auth.uid() = id);

-- Outlets: salesperson sees only outlets assigned to them
create policy "Salesperson sees own outlets" on outlets
  for select using (auth.uid() = assigned_salesperson_id);

-- Products: any logged-in user can view the catalog
create policy "Authenticated users can view products" on products
  for select using (auth.role() = 'authenticated');

-- Orders: salesperson can view/insert only their own orders
create policy "Salesperson sees own orders" on orders
  for select using (auth.uid() = salesperson_id);
create policy "Salesperson can insert own orders" on orders
  for insert with check (auth.uid() = salesperson_id);

-- Order items: visible/insertable if the parent order belongs to the user
create policy "Salesperson sees own order items" on order_items
  for select using (
    exists (select 1 from orders where orders.id = order_items.order_id and orders.salesperson_id = auth.uid())
  );
create policy "Salesperson can insert own order items" on order_items
  for insert with check (
    exists (select 1 from orders where orders.id = order_items.order_id and orders.salesperson_id = auth.uid())
  );

-- ============================================================
-- SAMPLE SEED DATA (products — safe to insert anytime)
-- ============================================================
insert into products (name, sku, price, stock) values
  ('Detergent Powder 1kg', 'DET-1KG', 120.00, 500),
  ('Cooking Oil 1L', 'OIL-1L', 165.00, 300),
  ('Biscuit Pack (12x)', 'BIS-12', 240.00, 200),
  ('Shampoo Sachet Box (48x)', 'SHM-48', 96.00, 400),
  ('Tea Powder 250g', 'TEA-250', 85.00, 350)
on conflict do nothing;

-- ============================================================
-- NOTE: Outlets must reference a real salesperson profile ID,
-- which only exists after you create a user. See README.md
-- Step 4 for how to create a demo salesperson and their outlets.
-- ============================================================
