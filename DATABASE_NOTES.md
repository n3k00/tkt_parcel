# Database Notes

## Database Package
The app uses Drift over SQLite:

- Runtime: `drift`, `sqlite3`, `sqlite3_flutter_libs`
- Native executor: `drift/native.dart`
- Code generation: `drift_dev` with `build_runner`

The database file is stored in the app documents directory as `tkt_parcel.sqlite`.

## Main Database File
Main file: `lib/data/local/database/app_database.dart`

This file declares `AppDatabase`, imports enum/model dependencies, wires table and DAO parts, defines `schemaVersion`, and owns migration behavior.

Relevant generated file:

- `lib/data/local/database/app_database.g.dart`

Do not edit the generated file manually; regenerate it after schema changes.

## Tables
- `Parcels`: main parcel/voucher records. Includes tracking ID, towns, sender/receiver data, parcel counts, charges, payment/status fields, sync metadata, dispatch/driver fields, lifecycle timestamps, image path, claim note, and split voucher metadata (`parent_parcel_id`, `split_index`, `split_count`). `tracking_id` is unique. Custom constraints enforce positive parcel count and non-negative charges/cash advance.
- `ParcelEvents`: event log rows linked to parcels by `parcel_id`; cascade deletes when the parent parcel is deleted.
- `Towns`: source/destination town list. Unique by `{type, townName}`. Source towns require a non-empty `city_code`; destination towns require `city_code` to be null.

Table definition files:

- `lib/data/local/database/tables/parcels_table.dart`
- `lib/data/local/database/tables/parcel_events_table.dart`
- `lib/data/local/database/tables/towns_table.dart`

DAO files:

- `lib/data/local/database/daos/parcels_dao.dart`
- `lib/data/local/database/daos/parcel_events_dao.dart`
- `lib/data/local/database/daos/towns_dao.dart`

## Current schemaVersion
Current Drift `schemaVersion` is `4`.

Backup validation also has a matching `_currentSchemaVersion = 4` in `lib/core/services/backup_restore_service.dart`. If the database schema version changes, check whether backup restore compatibility rules also need to change.

## Migration Strategy
`AppDatabase.migration` defines:

- `onCreate`: creates all tables and seeds default towns.
- `onUpgrade` from `< 2`: creates the `towns` table and seeds default towns.
- `onUpgrade` from `< 3`: adds parcel sync/dispatch-related columns if missing.
- `onUpgrade` from `< 4`: adds nullable split voucher columns (`parent_parcel_id`, `split_index`, `split_count`) if missing.

Column additions use `_addParcelColumnIfMissing`, which checks `PRAGMA table_info(parcels)` before calling `migrator.addColumn`.

Default towns are seeded with `InsertMode.insertOrIgnore`, so repeated seeding should not duplicate existing rows.

## Known Migration Risks
- Backup restore rejects database versions less than 1 or greater than `_currentSchemaVersion`; update that constant when intentionally supporting a new schema.
- Backup restore accepts older schema v1 databases that have `parcels` but no `towns`; Drift migration should create/seed towns after restore.
- Backup restore must remove SQLite sidecar files (`tkt_parcel.sqlite-wal`, `tkt_parcel.sqlite-shm`, `tkt_parcel.sqlite-journal`) when replacing the database file.
- Adding non-nullable columns without defaults can break upgrades for existing databases.
- Changing enum values for `ParcelStatus`, `PaymentStatus`, `SyncStatus`, or `TownType` can break stored text enum values.
- Changing table constraints may require explicit data cleanup during migration.
- `ParcelEvents` uses cascade delete from parcels; deleting a parcel also deletes its event history.
- Unique keys on `Parcels.trackingId` and `Towns(type, townName)` can cause insert conflicts if migration or sync code creates duplicates.

## Rules for Future Changes
- For any table or column change, update `schemaVersion`.
- Add an explicit `onUpgrade` branch for the new version.
- Never delete/drop/remove database objects or data without explicit approval. Do not run destructive SQL such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, broad `DELETE`, or destructive migration steps unless the user specifically approves the exact operation.
- Keep migrations additive when possible; avoid destructive changes unless the task explicitly calls for data migration.
- When adding required columns, provide safe defaults or migrate existing rows before enforcing non-null constraints.
- Update backup/restore schema compatibility if the new schema affects restored databases.
- Regenerate Drift code after changing `app_database.dart`, table files, DAO annotations, or Drift-related model types.
- Do not manually edit `app_database.g.dart`.
- Add or update repository/DAO tests for schema-sensitive behavior.

## Commands for Code Generation
Regenerate Drift output:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Recommended verification after database changes:

```powershell
flutter analyze
flutter test
```
