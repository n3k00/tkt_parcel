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

ZIP backup restore validates image entry paths before extraction and rejects
absolute or parent-directory paths. Keep this boundary check when changing
backup formats.

Generated database code lives in `lib/data/local/database/app_database.g.dart`. Regenerate it with:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Printer / Hardware Integration
The project uses `pos_printer_kit` for printer integration and includes Bluetooth/storage permissions. Printer-related code is organized under `lib/features/printer`, `lib/features/printing`, and core printer services. Voucher/label printing appears image-based, which helps preserve Myanmar text rendering on thermal printers.

Label Settings supports selectable parcel label stock sizes: `75 x 50 mm`
and `80 x 60 mm`. The selected size controls the label preview aspect ratio,
hidden image capture pixel size, and TSPL print command width/height in mm.
The `75 x 50 mm` label keeps the compact text layout. The `80 x 60 mm` label
uses a roomier layout with a right-side tracking-ID QR code, one-line address
value, two-line phone value, and separate Address / Qty rows to keep the label
easy to scan.
Because label sliders are shared across stock sizes, the `80 x 60 mm` render
path clamps extreme saved font/spacing values and scales down only if needed to
avoid print-preview overflow. Label Top, Horizontal, and Row Gap controls start
at `0` for every label size, including `80 x 60 mm`; the settings screen uses
the same effective range as the renderer so slider changes are visible in
preview and print.

Printer connect currently uses the package default `PrinterConnectPage`. Open it through `openPrinterConnectPage(...)` so Android Bluetooth/Nearby devices permissions are checked first. Avoid replacing the package UI unless explicitly requested. The app currently depends on `pos_printer_kit` branch `codex/fix-printer-connection-hangs` with package path `packages/pos_printer_kit`; that branch moves retry/disconnect-before-connect handling into the package/core layer.

Official voucher printing is server-first for new parcels: the app must call Supabase `create_parcel_with_counter(...)`, receive the official `tracking_id`, repaint the voucher with that ID, save locally, and only then print. Preview/local draft IDs are not authoritative.

If Supabase parcel creation succeeds but local save or physical print fails, do not delete the server parcel or reuse the tracking ID. The recovery workflow is to refresh/pull Parcel History, find the server-created official parcel, and reprint that same tracking ID.

Split Voucher behavior: if one voucher's parcel quantity must be split
across multiple drivers, do not create unrelated replacement vouchers. The
Supabase `split_parcel(parent_id, splits)` RPC creates child parcel rows linked
to the original parent row.
Child tracking IDs use `PARENT-A`, `PARENT-B`, etc. Example:
`TGI-260814-0001-A`. The parent status becomes `split` and must not be attached
to ledger/incoming workflows; child vouchers are physical vouchers and follow
the normal parcel lifecycle. Child rows copy sender, receiver, from town, and to
town from the parent; child `parcel_type` and `remark` are editable, child
quantity is operator-entered but the total cannot exceed parent quantity, child
charges and cash advance are manual non-negative values, and child payment
status stays the same as the parent. Planned columns include
`parent_parcel_id`, `split_index`, `split_count`, `split_created_at`, and
`split_created_by`. This is server-side only, not local-only. Current SQL also
rejects split parent tracking IDs in Android gate ledger/incoming flows; use
child voucher tracking IDs instead.

Server-to-local parcel pull sync is incremental after the first successful pull. The first sync for each signed-in account fetches all RLS-visible Supabase parcels, then stores the max successful server `updated_at` in an account-scoped SharedPreferences cursor key derived from `parcel_pull_last_synced_at`. Later pulls for that account fetch `updated_at > last cursor` only, then update its cursor only after local upserts finish. Never share one cursor across branch accounts on the same device.

Parcel History supports local filtering by tracking ID, receiver name, and receiver phone. Keep the search field mounted across empty/non-empty result states so typing a query that returns no rows does not drop keyboard focus.

Parcel History, parcel detail, and reprint are offline-capable for parcels already saved in the local Drift database. Creating a new official parcel remains online-only because it must call Supabase for the official tracking ID. If profile/server refresh fails while offline, the app may use the last cached staff profile to keep local branch filtering available.

Parcel form Total Charges UI accepts `0` as valid. Empty, invalid, or negative values are rejected; database and Supabase constraints allow non-negative total charges.

Voucher header branch contact information is server-owned: `branches.address` and `branches.phone_numbers` are the source of truth for voucher address/phone where available. Staff users edit these fields from Account / Branch Profile. Voucher preview/reprint, receipt settings preview, and label test preview/print prefer branch contact fields and fall back to local setup values only when branch fields are empty.

Account / Branch Profile shows when branch contact data was last loaded from the server. Staff can manually refresh branch profile data, and saving branch address/phone now refreshes the server profile before showing success.

Supabase `branches` is the source of truth for parcel From Town choices because
these are voucher-issuing offices/gates. Android pulls active branches and
caches them in SharedPreferences for offline fallback. The signed-in account's
branch town is auto-selected when the form opens, but users may choose another
active branch when needed.

Supabase `towns` is the central master for parcel To Town choices. It is
separate from `branches`; branches are login/account/counter/voucher-header
offices, while towns are route/destination master data. Android pulls active
destination towns ordered by `sort_order` and caches them in SharedPreferences
for offline fallback. Settings does not expose local From Town or To Town
management; Android users should not manage these values locally.

Tracking ID prefix is the issuing branch/account city code, not necessarily the selected `fromTown`. Example: a Lashio branch account printing a parcel with `fromTown = Taunggyi` should receive an `LSO-YYMMDD-NNNN` tracking ID.

Supabase `branches.id` is a stable text key used by related software and foreign
keys. Do not replace or rename existing IDs such as `source_tgi`, `source_lso`,
and `source_tcl`. `branches.branch_type` distinguishes `main` and `gate`.
Current gate branches are `gate_llm` / `LLM` / လွိုင်လင် and
`gate_kgt` / `KGT` / ကျိုင်းတုံ. Gate accounts can create vouchers using their
issuing branch city-code prefix. Android shows gate-only Drawer entries for
Main Ledger and Incoming Parcels.

Android gate operations are server-backed and intentionally separate from the
Windows ledger tables. Gate Main Ledger uses `gate_ledger_mains` and
`gate_ledger_entries`; it accepts existing tracking IDs only and settle marks
parcels as dispatched. Gate Incoming uses `gate_incoming_mains` and
`gate_incoming_entries`; it supports dispatched parcel tracking IDs and manual
roadside entries, claim-note-required pickup, manual-entry payment updates at
claim time, editable unpaid manual entries, and an irreversible gate-user
driver payment lock from unpaid to paid. Gate mutations use authenticated RPC wrappers from
`supabase/gate_operations.sql`.

Run Supabase SQL in this order for Android backend setup: `schema.sql`,
`drivers.sql`, then `gate_operations.sql`. `drivers.sql` is additive and
creates/enables RLS for the shared `public.drivers` master used by gate screens.
Android gate users can read active drivers; driver add/edit remains admin-side.

`create_parcel_with_counter(...)` is idempotent by `client_parcel_id`: if a
server parcel was already created for the same client parcel ID, the RPC returns
that existing row without incrementing the counter again. This protects retry
flows after local save/print failures.

Supabase app config must not hardcode the anon key. Pass `SUPABASE_ANON_KEY`
with `--dart-define` for run/build commands. App-private function access uses
explicit grants only; do not reintroduce `grant execute on all functions in
schema app_private` without a deliberate security review.

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
- Split voucher child parcels must be generated by server RPC only. Do not create split child tracking IDs locally.
- Never add a Supabase service-role key to Flutter source, dart defines, assets, or release scripts. The app may use the public anon key only.
- Do not hardcode the Supabase anon key in source. Use `--dart-define=SUPABASE_ANON_KEY=...` for run/build.
- Supabase public app tables should have RLS enabled, no `anon` table privileges, and only minimal `authenticated` table privileges. Do not grant `DELETE` or `TRUNCATE` to app roles.
- If local save/print fails after server parcel creation, keep the server parcel and recover by pull-refreshing Parcel History and reprinting; do not delete the server row or create a replacement tracking ID.
- Treat `parcels.cityCode` / Supabase `parcels.city_code` as the issuing branch city code for new official parcels. Do not infer parcel origin from the tracking prefix; use `fromTown` for the selected origin town.
- Keep printer connection UX on the package default connect page unless the user approves a custom UI.
- Keep branch and town concepts separate: do not store non-branch destination towns in `branches`.
- Use active Supabase `branches` for From Town choices and active Supabase `towns` for To Town choices. Keep both caches as offline fallbacks.
- Treat `branches.id` as an integration-stable text key. Never rename existing branch IDs without an explicit cross-software migration plan.
- Keep Android gate operation tables separate from Windows ledger/incoming tables unless an explicit cross-app migration is approved.

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
