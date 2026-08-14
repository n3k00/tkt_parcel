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
4. Run [`drivers.sql`](drivers.sql) for the shared driver master used by
   Android gate workflows.
5. Run [`gate_operations.sql`](gate_operations.sql) for Android gate Main
   Ledger and Incoming Parcels workflows.
6. Confirm seeded branches exist:

Safety rule: never delete/drop/remove database objects or data without explicit approval. Do not run destructive SQL such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, broad `DELETE`, or destructive migration steps unless the exact operation has been approved.

```sql
select * from public.branches order by city_code;
```

Expected source branches:

- `source_tgi` / `TGI`
- `source_lso` / `LSO`
- `source_tcl` / `TCL`

Expected gate branches:

- `gate_llm` / `LLM`
- `gate_kgt` / `KGT`

`branches.id` is an existing stable text key used by related software and
foreign keys. Do not replace it with a generated ID. `branches.branch_type`
distinguishes `main` and `gate` accounts. Gate branches can create vouchers;
their server-generated tracking IDs use their own city code prefix.

Authenticated app users can read active branch rows for the server-owned
From Town picker. Staff updates remain restricted to their own branch contact
fields.

Current-day zero counter rows are seeded for `LLM` and `KGT`. After that,
`create_parcel_with_counter(...)` creates each branch's new daily counter
automatically on the first voucher of the day.

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

## From Town Branches

Parcel From Town choices come from active `public.branches` rows. This keeps
voucher-issuing main branches and gates server-owned. Authenticated users may
read active branches for the form picker, while staff contact-field updates
remain restricted to their own branch.

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

- returns the existing parcel row when the same `client_parcel_id` is retried
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
Run the same call again with the same `p_client_parcel_id`; it should return
the already-created parcel without incrementing the counter.

For a complete verification script, run [`verify.sql`](verify.sql) after `schema.sql`.

## Current Auth Model

- Staff users are mapped to one branch through `staff_profiles.branch_id`.
- Admin users have `staff_profiles.role = 'admin'` and can access all branches.
- Branch voucher header contact fields live on `branches.address` and `branches.phone_numbers`.
- Staff users can update their own branch contact fields from the app Account / Branch Profile screen. Admin users can manage all branches.
- RLS is enabled for the public backend tables.
- `anon` should have no table privileges on app backend tables.
- `authenticated` should have only the app-required table privileges; destructive table privileges such as `DELETE` and `TRUNCATE` must not be granted.
- `app_private` functions use explicit `EXECUTE` grants only. Do not grant
  execute on all functions in `app_private`.
- `create_parcel_with_counter(...)` validates branch access and generates the server tracking ID.

## Next Phase

- Verify real Android print/save flow against Supabase for single-device and two-device counter behavior.
- Pull dispatch/claimed updates back into Drift.

## Android Gate Operations

Gate-only Android screens use dedicated tables so they do not change the
Windows ledger contract:

- `gate_ledger_mains`, `gate_ledger_entries`
- `gate_incoming_mains`, `gate_incoming_entries`

Gate Main Ledger accepts existing tracking IDs only. Settling marks attached
parcels as `dispatched` and locks the ledger. A parcel cannot be attached to a
second active gate ledger entry.

Gate Incoming accepts either an existing dispatched tracking ID or a manual
parcel entry. Existing parcels become `arrived` when attached. Claim requires a
note; existing parcels also become `claimed`. Manual parcel claim may update
paid/unpaid status. Tracking-ID attach first calls a read-only preview RPC and
shows parcel details; only operator confirmation performs the attach and
changes the parcel to `arrived`. Before driver payment, manual entries can be edited.
Removing an unclaimed existing parcel from an unpaid incoming list reverses its
receipt state from `arrived` back to `dispatched`, so it can be attached again.
Marking driver payment from `unpaid` to `paid` records the entered amount and
locks entry add/remove/edit operations while leaving claim
updates available.

Gate tables are RLS-protected. Android reads its own branch rows directly and
performs mutations through authenticated RPC wrappers only. Gate driver lists
are read-only in Android; driver add/edit remains Windows/Admin work.

## Drivers

Run [`drivers.sql`](drivers.sql) before `gate_operations.sql`. It creates
`public.drivers` if missing, enables RLS, grants authenticated users
non-destructive table access, and adds explicit policies:

- active gate staff can read active drivers for Android gate screens
- admin users can insert/update driver rows for admin tooling

No delete policy is granted.
