# FMCG Salesman App — MVP Setup Guide

A Flutter app for FMCG field salespeople: log in, see assigned outlets, record a
visit outcome (No Order / Follow-up / Place Order), and view order history.
Backend is entirely Supabase (Postgres + Auth) — no custom server, no Docker.

---

## What's included

```
fmcg_salesman_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                     # App entry + role-based auth gate
│   ├── config/supabase_config.dart   # Your Supabase URL + anon key go here
│   ├── models/                       # Outlet, Product, SalesOrder, Profile, AdminOrder,
│   │                                 # OrderItemDetail, BeatPlan, AttendanceRecord, LeaveRequest,
│   │                                 # AdminLeaveRequest
│   ├── services/                     # Auth, Outlet, Product, Order, Profile, AdminOrder,
│   │                                 # BeatPlan, Attendance, Leave, AdminUser, AdminLeave,
│   │                                 # AdminBeatPlan, AdminDashboard (Supabase calls)
│   ├── widgets/coming_soon.dart       # Shared "Coming Soon" dialog/placeholder screen
│   └── screens/
│       ├── login_screen.dart
│       ├── home/
│       │   ├── home_shell_screen.dart      # Bottom-nav shell: Home/Visits/Orders/Attendance/Profile
│       │   └── home_dashboard_screen.dart  # The Home tab (mockup screen)
│       ├── dashboard_screen.dart, outlet_detail_screen.dart, order_screen.dart,
│       │   order_history_screen.dart, add_outlet_screen.dart, outlet_picker_screen.dart,
│       │   today_route_screen.dart, attendance_screen.dart, apply_leave_screen.dart,
│       │   profile_screen.dart
│       └── admin/admin_home_screen.dart, admin_salesmen_screen.dart, add_salesman_screen.dart,
│           admin_dashboard_screen.dart, admin_order_detail_screen.dart  # Admin side
└── supabase/
    ├── schema.sql                          # Core DB schema + RLS + sample products (run first)
    ├── admin_migration.sql                 # Adds admin role support + policies (run second)
    ├── add_outlet_migration.sql            # Lets salespeople add new shops (run third)
    ├── company_id_login_migration.sql      # Supports the Company ID login screen (run fourth)
    ├── beat_and_attendance_migration.sql   # Beat plans ("Assigned Area") + attendance (run fifth)
    ├── leave_and_checkout_migration.sql    # Check-out + leave requests + attachments (run sixth)
    └── admin_management_migration.sql      # Admin "Manage Salesmen" (add/remove/routes) (run seventh)
```

---

## Step 1 — Create your Supabase project

1. Go to https://supabase.com → sign up / log in → **New Project**.
2. Pick a name, database password, and region. Wait ~2 minutes for it to spin up.
3. Once ready, go to **Project Settings → API**. Copy:
   - **Project URL**
   - **anon public key**

## Step 2 — Set up the database

1. In your Supabase project, open **SQL Editor → New query**.
2. Paste the entire contents of `supabase/schema.sql` and click **Run**.
   This creates all tables (`profiles`, `outlets`, `products`, `orders`,
   `order_items`), sets up Row Level Security so each salesperson only sees
   their own data, and inserts 5 sample products.

## Step 3 — Create a demo salesperson user

The login screen asks for a **Company ID** (e.g. `HUL-2025`), not an email —
but Supabase Auth still stores email/password underneath. The app maps a
Company ID to an email automatically: `HUL-2025` becomes
`hul-2025@fmcgsalesforce.app` (see `companyIdToEmail()` in
`lib/services/auth_service.dart`). So to create a demo user matching a given
Company ID, just create it with that mapped email:

1. In Supabase, go to **Authentication → Users → Add user**.
2. Create a user with email `hul-2025@fmcgsalesforce.app` (this is what you'll
   type as Company ID `HUL-2025` on the login screen) and a password of your
   choice. Confirm the email if asked (or disable "Confirm email" under
   **Authentication → Providers → Email** for the demo, so you can log in
   immediately without checking an inbox).
3. Go to **Table Editor → profiles** — you should see a row auto-created for
   this user (via the trigger in the schema). Copy that user's `id` (UUID).

> If you'd rather log in with a real email address instead of a Company ID,
> that works too — just type the full email (containing `@`) into the
> Company ID field and it's used as-is.

## Step 4 — Add demo outlets for that salesperson

In **SQL Editor**, run (replace `PASTE_USER_ID_HERE` with the UUID from Step 3):

```sql
insert into outlets (name, address, contact_person, contact_number, assigned_salesperson_id) values
  ('Sharma General Store', '12 MG Road, Andheri, Mumbai', 'Ramesh Sharma', '9820012345', 'PASTE_USER_ID_HERE'),
  ('New Era Kirana', '45 Station Road, Bandra, Mumbai', 'Suresh Patil', '9820054321', 'PASTE_USER_ID_HERE'),
  ('City Supermart', '7 Linking Road, Bandra West, Mumbai', 'Anita Rao', '9820098765', 'PASTE_USER_ID_HERE');
```

## Step 5 — Plug your credentials into the app

Open `lib/config/supabase_config.dart` and replace the placeholders:

```dart
static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
```

## Step 5b — Set up the Admin role

1. In **SQL Editor**, paste the contents of `supabase/admin_migration.sql` and
   run it. This adds an `admin_remarks` column, an `is_admin()` helper
   function, and RLS policies so admins can see and update every order
   (salespeople still only see their own — nothing changes for them).
2. Create a second demo user (e.g. `admin@demo.com`) the same way you did in
   Step 3, OR just promote your existing user to admin for a quick test.
3. Promote a user to admin — run in SQL Editor (replace the email):
   ```sql
   update profiles set role = 'admin'
   where id = (select id from auth.users where email = 'admin@demo.com');
   ```
4. Log into the app with that user — pick the **Admin / Manager** tab on the
   login screen first (the app checks the account's real role against the
   tab you picked, and blocks the login with a clear message if they don't
   match, so a salesperson account can't sneak in through the Admin tab or
   vice versa). You'll land on the **Admin Dashboard** with tabs for
   **Pending Approval** and **All Orders**. Tap a pending order to see its
   line items and Approve/Reject it (rejecting requires a reason).

> Note: one Supabase Auth user = one role at a time in this MVP. Use two
> separate demo accounts (one salesperson, one admin) to demo both sides.

## Step 5c — Enable "Add New Shop"

1. In **SQL Editor**, paste the contents of `supabase/add_outlet_migration.sql`
   and run it. This adds one RLS policy so a salesperson can insert a new
   outlet row, as long as they assign it to themselves — without this,
   the database silently rejects the insert.
2. That's it, no other setup needed. The app's dashboard already ships with
   an **Add New Shop** button and a search bar (see Code Walkthrough below).

## Step 5c-2 — "Add New Dealer" redesign (owner, GST, photos, GPS)

The **Add Dealer** button (Home tab quick action) now opens a full dealer
onboarding form: Dealer Name, Owner Name, Mobile Number, GST Number,
Address, Business Type (Retailer/Wholesaler/Distributor), Shop Front +
Business Card photos, and an auto-captured GPS location.

1. In **SQL Editor**, paste the contents of
   `supabase/add_dealer_fields_migration.sql` and run it. This adds the
   `gst_number`, `business_type`, `shop_front_photo_url`,
   `business_card_photo_url`, `latitude`, `longitude` columns to `outlets`,
   and creates a public `dealer-photos` storage bucket with policies so a
   salesperson can only upload into their own folder.
2. Run `flutter pub get` — this pulls in the two new packages the form
   needs: `image_picker` (camera/gallery capture) and `geolocator` (GPS).
3. **Add platform permissions.** Since this project only ships
   `pubspec.yaml` + `lib/` (see Step 7), these need to be added to the
   platform folders *after* you run `flutter create .`:

   **`android/app/src/main/AndroidManifest.xml`** — inside `<manifest>`, above `<application>`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```

   **`ios/Runner/Info.plist`** — inside the outer `<dict>`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Used to photograph the dealer's shop front and business card.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Used to attach a photo from your gallery.</string>
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Used to auto-capture the dealer's GPS location when onboarding.</string>
   ```

4. Owner Name and Mobile Number reuse the existing `contact_person` /
   `contact_number` columns from `add_outlet_migration.sql` (Step 5c), so
   that migration must be run first if you haven't already.

## Step 5d — Company ID login screen

1. In **SQL Editor**, paste the contents of `supabase/company_id_login_migration.sql`
   and run it. This only updates the "new user" trigger so it can read a
   `role` out of signup metadata (used if you ever create accounts via
   `AuthService.signUp()`); it doesn't change how sign-**in** works, since
   that's handled entirely client-side by mapping Company ID → email.
2. Open the app — the login screen now matches the SalesForce Pro mockup:
   - **Salesman / Admin-Manager tabs** — pick the one matching the account
     you're logging into. If it doesn't match the account's actual role in
     `profiles`, the app signs you back out and tells you which tab to use
     instead of silently letting you in.
   - **Company ID + Password** — Company ID is mapped to the underlying
     Supabase Auth email as described in Step 3.
   - **Remember Me** — saves your Company ID on-device (`shared_preferences`)
     and pre-fills it next time; unchecking it clears the saved value.
   - **Forgot Password?** — opens a dialog and calls Supabase's real
     `resetPasswordForEmail`. Note: this only delivers an email if the
     account's underlying address is a real inbox — the synthetic
     `@fmcgsalesforce.app` addresses used for demo Company IDs won't
     receive anything. For production, create users with real company
     email addresses so resets actually arrive.

## Step 5e — Salesman Home Dashboard

1. In **SQL Editor**, paste the contents of `supabase/beat_and_attendance_migration.sql`
   and run it. This adds two tables:
   - `beat_plans` — the "Assigned Area" banner at the top of the Home tab.
     In the full product an Admin would assign this the day before from an
     Admin screen (not built yet — see "What's intentionally left out"
     below). For now, insert a row directly via SQL — the migration file's
     bottom section has a ready-to-uncomment example:
     ```sql
     insert into beat_plans (salesperson_id, plan_date, zone_name, coverage_km)
     values ('PASTE_USER_ID_HERE', current_date, 'South Delhi Zone-3', 8.2)
     on conflict (salesperson_id, plan_date) do update
       set zone_name = excluded.zone_name, coverage_km = excluded.coverage_km;
     ```
     If no beat plan exists for today, the dashboard shows a friendly
     "No Area Assigned Yet" state instead of breaking.
   - `attendance` — backs the "Attendance" stat card and the "Start Shift"
     quick action (see below).
2. Log in as a salesperson (Salesman tab). You now land on a 5-tab bottom
   navigation shell instead of the bare outlet list:
   - **Home** — the new dashboard: greeting, Assigned Area banner, 4 live
     stat cards, Quick Actions, and a Today's Route preview.
   - **Visits** — the outlet list you had before (search, tap into a dealer,
     "Add New Shop" FAB) — unchanged, just renamed "My Dealers".
   - **Orders** — the existing order/visit history screen.
   - **Attendance** — today's check-in status + "Start Shift".
   - **Profile** — your name/role, and a working **Log Out** button.

### What's wired up on the Home dashboard

| Element | Behavior |
|---|---|
| Greeting + name | Time-of-day greeting ("Good Morning/Afternoon/Evening") + your `profiles.full_name` |
| Avatar (top right) | Tap to jump to the Profile tab |
| Notification bell | Shows a red dot if you have pending follow-ups; tapping opens a "Coming Soon" dialog (no notification system yet) |
| Assigned Area banner | Reads today's row from `beat_plans`; dealer count comes live from your assigned outlets |
| Today's Visits (x/y) | x = distinct dealers you logged a visit/order for today; y = total dealers assigned to you |
| Orders Placed | Count of today's orders with outcome `order_placed` |
| Pending Follow Ups | Count of your `follow_up_scheduled` orders, all-time (not just today) |
| Attendance | "Present" if you've checked in today via `attendance`, else "Not Started" |
| All 4 stat cards | Tappable — jump to the relevant tab (Visits, Orders, or Attendance) |
| Start Shift | Inserts today's `attendance` row (idempotent — tapping twice won't duplicate it) |
| View Route | "Coming Soon" dialog — turn-by-turn navigation isn't built |
| Add Dealer | Opens the existing "Add New Shop" form |
| Place Order | Opens a dealer picker → existing Place Order flow |
| Today's Route (preview + View All) | Live visited/pending status per dealer today, derived from real orders; "View All" opens the full list |

## Step 5f — Attendance calendar + Apply Leave

1. In **SQL Editor**, paste the contents of `supabase/leave_and_checkout_migration.sql`
   and run it. This adds:
   - `check_out_time` on the existing `attendance` table (so "End Shift" can
     record it and a real "hours worked" figure can be computed).
   - A `leave_requests` table (leave type, date range, reason, status,
     optional attachment path) with RLS.
   - A private **`leave-attachments`** storage bucket, with policies so each
     user can only read/write files inside their own folder
     (`leave-attachments/{their_user_id}/...`).
2. Run `flutter pub get` — this migration's screens use a new dependency,
   `file_picker`, for the optional leave attachment upload.
3. Open the **Attendance** tab. It's now a full page instead of a
   placeholder:
   - **Today card** — Status / Check In / Check Out, live. Tap **Start
     Shift** to check in (records the exact time); once checked in, the
     button becomes **End Shift**, which records check-out time and shows
     the hours worked. Both are safe to double-tap — they won't create
     duplicate records for the day.
   - **Status logic**: checking in before 10:00 AM marks the day
     **Present**; at/after 10:00 AM it's marked **Late**. Ending a shift
     that totals under 4 hours reclassifies the day as **Half Day**. These
     thresholds are placeholder business rules — tune `lateAfterHour` and
     `halfDayThresholdHours` in `attendance_service.dart` to match your
     company's actual policy.
   - **Monthly calendar** — Prev/Next arrows (capped at the current month)
     load real `attendance` rows for that month. Sundays and future dates
     always show as a grey dash (non-working / hasn't happened yet). A past
     working day with **no** attendance row is shown as a computed **Absent**
     (red) — this is derived on the fly, not stored, so it always reflects
     reality without needing a nightly job to mark people absent. Today's
     cell gets a blue ring.
   - **This Month card** — Days Present (present + late + half-day, i.e.
     "showed up"), Days Absent (computed, as above), Leaves Taken (sum of
     **approved** `leave_requests` days that fall in the shown month), and
     Working Hours (sum of each day's check-in→check-out span).
   - **Apply Leave** button (top right) opens the leave request form.
4. On the **Apply Leave** screen:
   - Pick a **Leave Type** (Casual/Sick/Emergency/Earned — single select).
   - Pick **Start Date** / **End Date** (real date pickers; end date can't
     be before start date).
   - Fill in a **Reason** (required before submitting).
   - **Attachment (optional)** — tap **Upload** to pick any file from your
     device; it's uploaded to the private `leave-attachments` bucket when
     you submit. Tap the ✕ to remove it before submitting.
   - **Past Requests** lists everything you've submitted, with a live
     status pill (PENDING/APPROVED/REJECTED).
   - **Submit Leave Request** inserts the row (and uploads the attachment,
     if any), then clears the form and refreshes Past Requests right there
     on the same screen so you can see it land immediately.
5. Leave requests can now be approved/rejected from the app itself — see
   **Step 5g** below.

## Step 5g — Admin Dashboard (Sales Overview + Manage Salesmen)

1. In **SQL Editor**, paste the contents of `supabase/admin_management_migration.sql`
   and run it. This adds:
   - A `status` column on `profiles` (`active`/`inactive`) used to
     soft-deactivate a salesman (a client app has no service-role key, so
     it can't delete an `auth.users` row outright — deactivating instead
     signs them out and blocks re-login, while keeping their order/outlet
     history intact).
   - An `admin_remarks` column on `leave_requests`, for an optional
     rejection note.
   - An **"Admin can update all profiles"** policy, so an Admin can flip
     someone else's `status`.
2. Logging in as an Admin now opens a **Sales Overview** home dashboard
   instead of going straight to the orders list:
   - **Stat cards** — Total Salesmen, Present Today, Total Orders, Pending
     Orders, Today's Visits, Revenue MTD — all computed live from
     `profiles`/`attendance`/`orders`.
   - **This Week — Orders vs Visits** — a simple bar chart of order count
     and distinct-outlet visit count per day, Monday through Saturday.
   - **Today's Attendance** — a donut of Present/Late/Absent.
   - **Quick Actions** — **Salesmen** and **Orders** are fully wired up;
     **Dealers** and **Reports** open a "Coming Soon" dialog (not built in
     this MVP yet).
3. Tapping **Salesmen** opens **Manage Salesmen**, with two tabs:
   - **Salesmen** — tap **Add Salesman** (top right) to create a new
     salesperson login (Full Name, Company ID, temporary password — share
     the Company ID + password with them so they can log in). Each row
     shows that salesman's zone for today (from `beat_plans`) and has
     **Assign Route** (zone name, optional coverage in km, and a date —
     defaults to today; assigning again for the same day updates it) and
     **Remove**/**Reactivate** (the soft-deactivate flow described above).
   - **Leave Requests** — every request across every salesman, newest
     first, with **Approve**/**Reject** (optional reason) on anything
     still `pending`.
4. Tapping **Orders** opens the existing Pending Approval / All Orders
   screen from Step 5b, unchanged.

## Step 6 — Install Flutter (if you haven't already)

Follow https://docs.flutter.dev/get-started/install for your OS, then confirm:
```bash
flutter doctor
```

## Step 7 — Run the app

Since this project only ships `pubspec.yaml` + `lib/`, you need Flutter to
generate the platform folders (android/ios/web) once:

```bash
cd fmcg_salesman_app

# Generate platform folders into this existing project
flutter create .

# Install dependencies
flutter pub get

# Run on a connected device/emulator, or Chrome for a quick demo
flutter run -d chrome
```

Log in with the Company ID for the demo user you created in Step 3 (e.g.
`HUL-2025` if you created `hul-2025@fmcgsalesforce.app`), making sure the
**Salesman** tab is selected. You'll land on the **Home** tab of a 5-tab
bottom nav (Home/Visits/Orders/Attendance/Profile). Switch to **Visits** to
see the 3 sample outlets, tap into one, place an order from the 5 sample
products, or record a "No Order"/"Follow-up" outcome — then check the
**Orders** tab, and watch the Home tab's stat cards update to match.

---

## Code Walkthrough

**`main.dart`** — Initializes Supabase once at startup, then `AuthGate`
listens to `supabase.auth.onAuthStateChange` and shows `LoginScreen`,
`HomeShellScreen` (salesperson), or `AdminDashboardScreen` depending on
whether a session exists and the signed-in profile's role. This is the
entire auth routing logic — no manual navigation stack management needed
for login/logout.

**`screens/home/home_shell_screen.dart`** — The salesperson's bottom-nav
shell (Home/Visits/Orders/Attendance/Profile). Uses `IndexedStack` so
switching tabs doesn't reset each tab's scroll position or in-flight
network calls. Passes a `_goToTab` callback down into `HomeDashboardScreen`
so its stat cards and avatar can jump to another tab.

**`screens/home/home_dashboard_screen.dart`** — The Home tab. Loads
profile, outlets, today's orders, pending-follow-up count, today's beat
plan, and today's attendance in parallel (`Future.wait`), then derives the
stat values from that data (see the table in Step 5e above). Every tap
target calls real service methods or navigates to a real screen — nothing
is a dead button.

**`screens/login_screen.dart`** — Matches the SalesForce Pro mockup:
gradient header, a **Salesman / Admin-Manager** segmented tab, **Company ID**
+ **Password** fields, **Remember Me**, **Forgot Password?**, and the
**Sign In** button. On submit it calls `AuthService.signIn()`, then fetches
the profile via `ProfileService` and compares its `role` against the tab you
picked — a mismatch signs you back out with a message telling you which tab
to use, rather than routing you to the wrong dashboard. "Remember Me" reads/
writes the Company ID via `shared_preferences` in `initState`/`_login()`.
"Forgot Password?" opens a small dialog that calls
`AuthService.resetPassword()`.

**`services/`** — Each service is a thin wrapper around a Supabase table:
- `AuthService` → `signIn`/`signUp` (map a Company ID to the underlying
  Supabase Auth email via `companyIdToEmail()`), `resetPassword`, `signOut`
- `BeatPlanService.getTodayPlan()` → today's `beat_plans` row, or `null`
- `AttendanceService.getTodayAttendance()` / `getAttendanceForMonth()` /
  `checkIn()` / `checkOut()` → check-in stamps 'present' or 'late' depending
  on time of day; check-out records the time and reclassifies short shifts
  as 'half_day'. Both are idempotent (safe to call twice)
- `LeaveService.submitLeaveRequest()` / `getMyLeaveRequests()` /
  `getAttachmentSignedUrl()` → inserts a leave request (uploading an
  attachment to private Storage first, if provided) and fetches your own
  request history
- `OutletService.getMyOutlets()` → filters outlets where `assigned_salesperson_id`
  matches the logged-in user (RLS also enforces this server-side, so even a
  buggy client-side filter can't leak other salespeople's outlets);
  `createOutlet()` inserts a new outlet row stamped with the current user's id
- `ProductService.getAllProducts()` → simple catalog fetch
- `OrderService` → `placeOrder()` inserts one row into `orders` then bulk-inserts
  into `order_items`; `recordVisitOutcome()` handles the No Order/Follow-up
  paths (no product line items); `getMyOrders()` fetches order history joined
  with the outlet name

**`screens/`** — Standard `FutureBuilder` pattern throughout: fetch on
`initState`, show a spinner while loading, render the list on success. The
`DashboardScreen` → `OutletDetailScreen` → `OrderScreen` chain mirrors your
original workflow diagram: pick an outlet, choose an outcome, place an order
if applicable.

**Add New Shop + Search (`DashboardScreen`, `AddOutletScreen`)** — A
`FloatingActionButton` opens `AddOutletScreen`, a simple form (shop name is
required; address/contact person/contact number are optional). On save it
calls `OutletService.createOutlet()`, which inserts the row with
`assigned_salesperson_id` set to the current user, then pops back to the
dashboard with the new `Outlet` so it's immediately visible in the list —
no extra tap needed to "find" the shop you just added. The search bar above
the list filters the already-loaded outlets by name or address as you type;
it's instant (no network round-trip) since a salesperson's outlet list is
small enough to filter client-side. This depends on `add_outlet_migration.sql`
being run (Step 5c) — without its RLS policy, Supabase rejects the insert
even though the button and form still work fine.

**Admin side (`screens/admin/`)** — `AdminDashboardScreen` has two tabs:
Pending Approval and All Orders (both just different Supabase queries via
`AdminOrderService`). Tapping a pending order opens
`AdminOrderDetailScreen`, which fetches the order's line items and shows
Approve/Reject buttons. Reject requires typing a reason, which gets saved
to `orders.admin_remarks` — this is the "mandatory rejection reason" from
the original workflow spec.

**Role-based routing (`main.dart`)** — After a session exists, `AuthGate`
fetches the user's `profiles.role` and shows `AdminDashboardScreen` if
`role == 'admin'`, otherwise the salesperson `DashboardScreen`. This is the
same pattern your original wireframe's login screen used (route by role)
but implemented via a database field rather than a UI toggle.

**Why RLS instead of app-side role checks** — the Admin policies added in
`admin_migration.sql` (via the `is_admin()` helper) mean that even if
someone tampered with the Flutter app to try to view another salesperson's
orders, Supabase itself would block it at the database level. The app's
role check controls what you *see*; RLS controls what you're *allowed to
fetch at all* — the real security boundary.

**Why Supabase instead of a custom backend:** you get Postgres, authentication,
auto-generated REST access, and row-level security (real per-user data
isolation) without writing or deploying any server code — which is why there's
no Docker, no FastAPI, no separate hosting step for this MVP. It's the fastest
path from zero to a working demo.

---

## What's intentionally left out of this MVP (add later)

- GPS check-in / geofencing, shop photo capture
- Warehouse/dispatch flow
- Real-time status updates (salesperson currently needs to refresh Order
  History to see if their order got approved/rejected — Supabase Realtime
  subscriptions would fix this next)
- Offline mode / local sync
- WhatsApp/push notifications (the Home dashboard's bell icon is wired to
  show "Coming Soon" for now)
- Live route mapping/navigation ("View Route" quick action is "Coming Soon";
  "Today's Route" itself is real data — see Step 5e)
- An Admin screen to assign `beat_plans` — today you seed it via SQL (Step
  5e); a real Admin UI for "assign this salesperson's area for tomorrow"
  would be a natural next addition to `screens/admin/`
- An Admin screen to assign `beat_plans` — today you seed it via SQL (Step
  5e); a real Admin UI for "assign this salesperson's area for tomorrow"
  would be a natural next addition to `screens/admin/`
- An Admin screen to approve/reject `leave_requests` — today you do it via
  SQL (Step 5f); the RLS policies (`is_admin()` can select/update all rows)
  are already in place, so an Admin UI just needs to be built on top
- Geo-located check-in/out — you mentioned wanting this later. The
  `attendance` table and `checkIn()`/`checkOut()` calls are the natural
  place to add `latitude`/`longitude` columns and capture location (e.g.
  via the `geolocator` package) once you're ready for it
- Monthly attendance history beyond the current calendar view (e.g. year-over-
  year trends), and admin-side attendance reports
- A real multi-tenant `companies` table — today "Company ID" is really a
  per-user login identifier (mapped 1:1 to a Supabase Auth email), not a
  shared company account with multiple salespeople under one ID. Adding a
  `companies` table + a `company_id` column on `profiles`/`outlets`/`products`
  would let you scope data per-company instead of per-salesperson.

These were all in the fuller workflow spec — Salesperson + Admin approve/
reject are done; the rest builds on top of this same pattern (a new role,
or a new screen reading/writing the same Supabase tables).
