# Database

## Local Drift database

The local SQLite database is defined in `lib/data/local/database/app_database.dart`. Current `schemaVersion` is `4` and the principal tables are parcels, parcel events, and towns, accessed through their DAOs.

For a schema change:

1. Back up or confirm a tested rollback path.
2. Change the table definition and increment `schemaVersion`.
3. Add a data-preserving `onUpgrade` migration for every supported old version.
4. Regenerate Drift code with `dart run build_runner build --delete-conflicting-outputs`.
5. Test both a clean database and an upgrade containing existing data.

Never delete the database file, reset all data, drop tables/columns, or use a destructive migration without the user's explicit approval.

## Supabase

Supabase is the server source of truth for staff access, branches, towns, official parcels, counters, split vouchers, drivers, and gate operations. Apply repository SQL in its documented order and verify backups before live migrations. Public tables must keep RLS enabled with minimal role grants; app roles must not receive destructive privileges.

Official tracking IDs come from authenticated RPCs such as `create_parcel_with_counter(...)` and `split_parcel(...)`. The public anon key is runtime configuration only. A service-role key must never be included in the Flutter app, source control, assets, logs, or build commands stored in the repository.

This label-layout change does not alter either the Drift schema or Supabase schema.
