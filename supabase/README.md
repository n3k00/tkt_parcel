# Supabase Backend Prototype

This folder contains the first backend contract for future TKT Parcel sync.

## Scope

- Keep Android app offline-first with Drift as the local source.
- Use Supabase/Postgres as the server source for multi-device sync later.
- Generate server-side tracking IDs with a transaction-safe counter.
- New official parcels are server-created first; the app should print only after receiving the server `tracking_id`.
- Do not blind-sync old local-only printed parcels. Old local-only parcels remain local history unless a separate legacy import plan is approved.
- Leave Windows app driver, dispatch, claimed, and ledger workflows for the next phase.

## Apply Schema

1. Create a Supabase project.
2. Open `SQL Editor`.
3. Run [`schema.sql`](schema.sql).
4. Confirm seeded branches exist:

Safety rule: never delete/drop/remove database objects or data without explicit approval. Do not run destructive SQL such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, broad `DELETE`, or destructive migration steps unless the exact operation has been approved.

```sql
select * from public.branches order by city_code;
```

Expected source branches:

- `source_tgi` / `TGI`
- `source_lso` / `LSO`
- `source_tcl` / `TCL`

## Town Master

Destination town choices are centralized in `public.towns` instead of being
managed by each device. Android users should not add To Town rows locally.

`public.towns` stores:

- `name_mm`: Myanmar town name, unique.
- `name_en`: optional English name.
- `code`: optional short code, unique when present.
- `sort_order`: stable app/report ordering.
- `active`: inactive towns are hidden from staff users.

The seed list contains 33 active towns from the current route notes. `ခိုလန်`
is treated as the same town as `ခိုလမ်`, so only `ခိုလမ်` is seeded.

Authenticated app users have read-only access to active towns. Town creation,
editing, and deactivation should be done from Supabase/admin tooling until a
dedicated admin workflow is approved.

## Server Counter

Tracking ID format:

```text
[CityCode]-[YYMMDD]-[RunningNumber]
```

`CityCode` means the issuing branch/account city code. It is not necessarily the selected parcel `from_town`. For example, a Lashio branch account can print a parcel with `from_town = Taunggyi`; the tracking ID should still use `LSO`.

Counter scope:

```text
issuing branch city_code + service_date
```

Use `create_parcel_with_counter(...)` for backend-created parcels. The function:

- validates parcel amount/count fields
- validates branch access and uses the issuing branch city code
- increments `parcel_counters`
- generates `tracking_id`
- inserts `parcels`
- returns the created parcel row

## Example RPC Test

`create_parcel_with_counter(...)` requires an authenticated user with an active `staff_profiles` row. Test it from the app or an authenticated API client after creating staff accounts.

The example uses PostgreSQL Unicode escape strings for Burmese town names so the SQL file stays encoding-safe on Windows.

```sql
select *
from public.create_parcel_with_counter(
  p_client_parcel_id := 'client-test-001',
  p_device_id := null,
  p_branch_id := 'source_tgi',
  p_from_town := U&'\1010\1031\102C\1004\103A\1000\103C\102E\1038',
  p_to_town := U&'\1010\102C\1001\103B\102E\101C\102D\1010\103A',
  p_city_code := 'TGI',
  p_sender_name := 'Ko Aung',
  p_sender_phone := '0912345678',
  p_receiver_name := 'Ma Su',
  p_receiver_phone := '0998765432',
  p_parcel_type := 'General',
  p_number_of_parcels := 1,
  p_total_charges := 7000,
  p_payment_status := 'unpaid',
  p_cash_advance := 0,
  p_remark := 'Test parcel'
);
```

Run the same call with a different `p_client_parcel_id`; the running number should increment.

For a complete verification script, run [`verify.sql`](verify.sql) after `schema.sql`.

## Current Auth Model

- Staff users are mapped to one branch through `staff_profiles.branch_id`.
- Admin users have `staff_profiles.role = 'admin'` and can access all branches.
- Branch voucher header contact fields live on `branches.address` and `branches.phone_numbers`.
- Staff users can update their own branch contact fields from the app Account / Branch Profile screen. Admin users can manage all branches.
- RLS is enabled for the public backend tables.
- `anon` should have no table privileges on app backend tables.
- `authenticated` should have only the app-required table privileges; destructive table privileges such as `DELETE` and `TRUNCATE` must not be granted.
- `create_parcel_with_counter(...)` validates branch access and generates the server tracking ID.

## Next Phase

- Verify real Android print/save flow against Supabase for single-device and two-device counter behavior.
- Pull dispatch/claimed updates back into Drift.
