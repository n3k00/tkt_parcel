# Project Context

## Project Summary
TKT Parcel is an offline-first Flutter parcel voucher app, currently focused on Android counter operations. It creates parcel vouchers locally, stores parcel data in SQLite, supports voucher preview/reprint flows, and integrates with Bluetooth/thermal printer workflows.

## Tech Stack
- Framework: Flutter / Dart.
- State management: Riverpod (`flutter_riverpod`).
- Local database: Drift over SQLite (`drift`, `sqlite3`, `sqlite3_flutter_libs`).
- Code generation: `drift_dev` with `build_runner`.
- Local settings/storage: `shared_preferences`, `path_provider`.
- Printing/hardware: `pos_printer_kit` from GitHub, Bluetooth permissions via `permission_handler`, image-based printing helpers.
- Media/files: `image_picker`, `file_picker`, `image`, `archive`.
- QR rendering: `qr_flutter`.

## App Structure
- `lib/main.dart`: default entrypoint; bootstraps app config from dart defines.
- `lib/app/`: app shell, provider exports, and route generation.
- `lib/core/`: shared config, constants, services, theme, layout, errors, utilities, and extensions.
- `lib/data/`: local persistence, models, mappers, and repositories.
- `lib/data/local/database/`: Drift database, DAOs, table definitions, and generated database code.
- `lib/features/`: feature modules such as parcel, voucher, printer/printing, settings, sync, arrival, auth, dashboard, and dispatch.
- `windows/runner/`: generated/native Windows runner files.
- `android/`: Android app/build configuration and platform integration.

## State Management Pattern
This app uses Riverpod providers, not GetX. Repositories and services are exposed through providers, UI state is handled through Riverpod notifiers/providers, and feature screens consume state with Flutter/Riverpod widgets. Keep new state changes consistent with the existing provider/repository/service pattern unless architecture changes are explicitly requested.

## Database
The local database is Drift-backed SQLite. The main database file is `lib/data/local/database/app_database.dart`, with table parts for parcels, parcel events, and towns plus DAO parts for database access. Current `schemaVersion` is `3`.

Migration rules are defined in `AppDatabase.migration`: new installs create all tables and seed default towns; upgrades from older versions create towns and add parcel sync/dispatch-related columns if missing. For any schema change, update `schemaVersion`, add an `onUpgrade` migration, update table definitions, and regenerate Drift code.

Backup restore replaces `tkt_parcel.sqlite` and must remove SQLite sidecar files (`-wal`, `-shm`, `-journal`). Older schema v1 backups may not contain `towns`; restore should allow them so Drift can migrate and seed towns on reopen.

Generated database code lives in `lib/data/local/database/app_database.g.dart`. Regenerate it with:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Printer / Hardware Integration
The project uses `pos_printer_kit` for printer integration and includes Bluetooth/storage permissions. Printer-related code is organized under `lib/features/printer`, `lib/features/printing`, and core printer services. Voucher/label printing appears image-based, which helps preserve Myanmar text rendering on thermal printers.

Printer connect currently uses the package default `PrinterConnectPage`. Open it through `openPrinterConnectPage(...)` so Android Bluetooth/Nearby devices permissions are checked first. Avoid replacing the package UI unless explicitly requested. The app currently depends on `pos_printer_kit` branch `codex/fix-printer-connection-hangs` with package path `packages/pos_printer_kit`; that branch moves retry/disconnect-before-connect handling into the package/core layer.

Official voucher printing is server-first for new parcels: the app must call Supabase `create_parcel_with_counter(...)`, receive the official `tracking_id`, repaint the voucher with that ID, save locally, and only then print. Preview/local draft IDs are not authoritative.

If Supabase parcel creation succeeds but local save or physical print fails, do not delete the server parcel or reuse the tracking ID. The recovery workflow is to refresh/pull Parcel History, find the server-created official parcel, and reprint that same tracking ID.

Server-to-local parcel pull sync is incremental after the first successful pull. The first sync for each signed-in account fetches all RLS-visible Supabase parcels, then stores the max successful server `updated_at` in an account-scoped SharedPreferences cursor key derived from `parcel_pull_last_synced_at`. Later pulls for that account fetch `updated_at > last cursor` only, then update its cursor only after local upserts finish. Never share one cursor across branch accounts on the same device.

Parcel History supports local filtering by tracking ID, receiver name, and receiver phone. Keep the search field mounted across empty/non-empty result states so typing a query that returns no rows does not drop keyboard focus.

Parcel History, parcel detail, and reprint are offline-capable for parcels already saved in the local Drift database. Creating a new official parcel remains online-only because it must call Supabase for the official tracking ID. If profile/server refresh fails while offline, the app may use the last cached staff profile to keep local branch filtering available.

Parcel form Total Charges UI accepts `0` as valid. Empty, invalid, or negative values are rejected; database and Supabase constraints allow non-negative total charges.

Voucher header branch contact information is server-owned: `branches.address` and `branches.phone_numbers` are the source of truth for voucher address/phone where available. Staff users edit these fields from Account / Branch Profile. Voucher preview/reprint, receipt settings preview, and label test preview/print prefer branch contact fields and fall back to local setup values only when branch fields are empty.

Account / Branch Profile shows when branch contact data was last loaded from the server. Staff can manually refresh branch profile data, and saving branch address/phone now refreshes the server profile before showing success.

Supabase `towns` is the central town master for parcel From/To choices. It is separate from `branches`; branches are login/account/counter/voucher-header offices, while towns are route/destination master data. Android pulls active destination towns from Supabase ordered by `sort_order` and caches them in SharedPreferences for offline fallback. Settings does not expose To Town add/edit/read-only management; Android users should not manage To Town values locally.

Tracking ID prefix is the issuing branch/account city code, not necessarily the selected `fromTown`. Example: a Lashio branch account printing a parcel with `fromTown = Taunggyi` should receive an `LSO-YYMMDD-NNNN` tracking ID.

## Current Known Issues
- Requested Gradle paths `android/app/build.gradle` and `android/build.gradle` do not exist; this project appears to use Kotlin DSL Gradle files instead.
- Real-device release verification is still required before production: staff login, branch visibility, two-device tracking ID uniqueness, printer connection/printing, and Parcel History reprint recovery.

## Coding Rules for Codex
- Do not refactor unrelated files.
- Make minimal, task-focused changes.
- Ask before changing architecture.
- For database schema changes, update `schemaVersion` and migrations.
- Never delete/drop/remove database objects or data without explicit approval. Do not use destructive SQL such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, broad `DELETE`, or destructive migration steps unless the user specifically approves the exact operation.
- For generated files, run `dart run build_runner build --delete-conflicting-outputs` after changing Drift tables/database definitions.
- Inspect only relevant files for each task; do not load the whole project at once.
- Prefer existing Riverpod/provider/repository/service patterns.
- Do not edit generated files manually unless there is a specific reason and the generator cannot be used.
- Do not blind-sync old local-only parcels to Supabase. Old printed/local-only parcels remain local history unless a separate legacy import plan is explicitly approved.
- New official parcels must be created through Supabase `create_parcel_with_counter(...)`; do not generate official tracking IDs on-device.
- Never add a Supabase service-role key to Flutter source, dart defines, assets, or release scripts. The app may use the public anon key only.
- Supabase public app tables should have RLS enabled, no `anon` table privileges, and only minimal `authenticated` table privileges. Do not grant `DELETE` or `TRUNCATE` to app roles.
- If local save/print fails after server parcel creation, keep the server parcel and recover by pull-refreshing Parcel History and reprinting; do not delete the server row or create a replacement tracking ID.
- Treat `parcels.cityCode` / Supabase `parcels.city_code` as the issuing branch city code for new official parcels. Do not infer parcel origin from the tracking prefix; use `fromTown` for the selected origin town.
- Keep printer connection UX on the package default connect page unless the user approves a custom UI.
- Keep branch and town concepts separate: do not store non-branch destination towns in `branches`.

## Useful Commands
Run dev flavor:

```powershell
flutter run --flavor dev -t lib/main_dev.dart
```

Run prod flavor:

```powershell
flutter run --flavor prod -t lib/main_prod.dart
```

Default run:

```powershell
flutter run
```

Build dev APK:

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

Build prod APK:

```powershell
flutter build apk --release --flavor prod -t lib/main_prod.dart
```

Analyze and test:

```powershell
flutter analyze
flutter test
```

Regenerate Drift/build_runner outputs:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Next Recommended Documentation Files
- `RELEASE_CHECKLIST.md`: MVP release readiness checklist for auth, Supabase, two-device tracking, branch visibility, printer, build, and go/no-go checks.
- `DATABASE_NOTES.md`: Drift schemaVersion/migrations durable notes.
- `TASK_LOG.md`: ongoing feature/task decisions across Codex threads.
- `CODEX_RULES.md`: optional; current Codex rules are already captured here, but a dedicated file may help if rules grow.
