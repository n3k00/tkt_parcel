# Task Log

## Current Status
TKT Parcel is an offline-first Flutter parcel voucher app focused on Android counter operations. It uses Riverpod for state management and Drift/SQLite for local parcel data. The project has durable context documentation in `PROJECT_CONTEXT.md` and database-specific notes in `DATABASE_NOTES.md`.

Latest full product/release status: Unknown / needs confirmation.

## Completed Work
- Created `PROJECT_CONTEXT.md` for future Codex threads.
- Created `DATABASE_NOTES.md` for Drift schema and migration guidance.
- Created `RELEASE_CHECKLIST.md` for final MVP release readiness checks.
- Updated release readiness basics: `pubspec.yaml` description now describes TKT Parcel, release builds no longer fall back to debug signing, and README documents Supabase dart-define usage plus the no-service-role-key rule.
- Bumped production release version to `1.0.10+13`.
- Fixed backup restore reliability by deleting SQLite sidecar files (`-wal`, `-shm`, `-journal`) during database replacement and allowing older schema v1 backups to restore so Drift can migrate them.
- Fixed Total Charges UI validation to accept `0` while still rejecting empty, invalid, or negative values.
- Created Supabase project `tkt-transport-system` / `bcfxcbkezjopwlgsaszb` in `ap-southeast-1`.
- Applied Supabase backend schema and verified initial branch/counter prototype.
- Hardened live Supabase table grants for production readiness: removed `anon` table privileges and removed destructive/broad table privileges from `authenticated`, leaving only app-required SELECT/INSERT/UPDATE grants under RLS.
- Added Supabase Auth/RLS backend model with `staff_profiles`, branch-scoped policies, admin access policies, private RLS helper functions, and authenticated parcel counter RPC.
- Changed Supabase tracking ID format to server-generated `CITY-YYMMDD-NNNN`; counters are scoped by `city_code + service_date`.
- Updated local tracking ID helper and local counter preview logic to match `CITY-YYMMDD-NNNN` and city/date scope.
- Changed tracking prefix semantics: `CITY` now means issuing branch/account city code, not selected From Town. Example: Lashio account + Taunggyi From Town prints `LSO-YYMMDD-NNNN`.
- Added Flutter Supabase client initialization, staff login gate, account screen/sign out flow, and branch profile fetch.
- Fixed login/sign-out navigation so successful authentication returns to the root `AuthGate` instead of bypassing staff profile checks by opening Home directly. Added a simple auth splash/loading screen and polished the staff login UI.
- Added Supabase branch contact fields (`branches.address`, `branches.phone_numbers`), allowed staff to update their own branch contact fields, moved voucher header contact editing into Account / Branch Profile, and made voucher header setup prefer branch contact fields.
- Added Supabase `towns` master schema and seed list for 33 active route towns. `ခိုလန်` is normalized to `ခိုလမ်`; town master data is separate from `branches`.
- Updated Android To Town handling to fetch active Supabase towns ordered by `sort_order` and cache them in SharedPreferences for offline fallback. Removed Settings > To Town management entirely.
- Added Account / Branch Profile refresh/status UX: it shows last server load time, supports manual refresh, and save success now means branch contact data was saved and refreshed from the server.
- Hid local voucher header text editing from Settings; local `businessAddress` and `businessPhone` remain fallback/legacy values only. Receipt settings preview and label settings test print now prefer branch contact fields when available.
- Implemented server-first official voucher creation: `Print and Save` calls Supabase `create_parcel_with_counter(...)`, receives the official `tracking_id`, repaints the voucher, saves the synced parcel locally, and then prints.
- Decided that if server parcel creation succeeds but local save/print fails, the server-created parcel remains the source of truth; the operator should refresh Parcel History and reprint the same official tracking ID.
- Implemented server-to-local pull sync for visible Supabase parcels. Home silently refreshes from server, and Parcel List supports pull-to-refresh. Pull sync does not upload old local-only parcels.
- Changed pull sync to incremental mode: first sync fetches all RLS-visible parcels, stores max successful server `updated_at` in SharedPreferences key `parcel_pull_last_synced_at`, and later pulls fetch only rows where `updated_at` is newer than that cursor.
- Fixed branch-account switching on one device by scoping the incremental parcel pull cursor per signed-in Supabase user. A Tachileik sync cursor no longer prevents the first Lashio pull from downloading older Lashio parcels.
- Fixed Parcel History search focus loss when a query returns no results. Search supports tracking ID, receiver name, and receiver phone, and the search field stays focused while the result list changes.
- Fixed To Town settings refresh behavior so adding/deleting destination towns refreshes the Parcel Create form town picker.
- Updated Parcel History status indicators: list item status bar now uses `received = red`, `dispatched = amber/yellow`, `arrived = green`, and `claimed = blue`; `cancelled` remains deferred for a later workflow.
- Added Parcel List AppBar status filtering for `All`, `Received`, `Dispatched`, `Arrived`, and `Claimed`. `Cancelled` is intentionally not exposed yet.
- Made saved parcel history/detail/reprint more offline-friendly: staff profile is cached after a successful load for local branch filtering, and voucher reprint falls back to local setup if branch profile refresh is unavailable.
- Printer connection uses the package default `PrinterConnectPage`; custom connect UI was tried and rejected. Keep the default UI unless explicitly requested.
- Updated `pos_printer_kit` dependency to Git branch `codex/fix-printer-connection-hangs` with path `packages/pos_printer_kit`; the package/core layer handles connection retry and disconnect-before-connect behavior.
- Existing app structure includes parcel creation, voucher preview/reprint flows, settings, sync placeholders, and printer/printing feature areas.
- Existing database structure includes parcels, parcel events, and towns with `schemaVersion = 3`.
- Existing commands are documented for Flutter run/build/test and Drift code generation.
- Prepared production release `1.0.10+13` after moving To Town choices to Supabase town master and removing Settings To Town management.
- Added the Supabase gate-branch foundation without deleting or renaming existing branch data: `branches.branch_type` (`main | gate`), `gate_llm` / `LLM` / လွိုင်လင်, and `gate_kgt` / `KGT` / ကျိုင်းတုံ. Seeded current-day zero counters for `LLM` and `KGT`; future daily counters are created automatically by the existing voucher RPC.
- Updated Android staff profile fetch/cache mapping with `branches.branch_type`. Gate accounts now see Drawer entries for Main Ledger and Incoming Parcels. These screens are routed empty states only; gate transaction RPCs and operational UI remain a separate implementation phase.
- Changed Android From Town handling to use active Supabase `branches`, cached in SharedPreferences for offline fallback. The signed-in account branch is auto-selected on form load. Removed Settings > From Town local-default management; To Town continues to use Supabase `towns`.
- Implemented Android gate operations as separate Supabase-backed workflows: `gate_ledger_mains`, `gate_ledger_entries`, `gate_incoming_mains`, and `gate_incoming_entries`, with own-branch RLS and authenticated transactional RPCs. Gate Main Ledger supports driver selection, tracking-ID attach, soft remove, and settle-to-dispatched. Gate Incoming supports driver selection, existing dispatched parcel attach-to-arrived, manual parcel entry, unpaid manual-entry edit, soft remove, claim-note-required pickup, and irreversible gate-user driver-payment locking.
- Fixed gate tracking-ID prompt dialog controller lifecycle. Incoming and Main Ledger prompts now own and dispose their `TextEditingController` inside the dialog widget after route removal, avoiding the Flutter `TextEditingController was used after being disposed` assertion.
- Updated Gate Incoming list scanning UX: list rows now lead with receiver name and receiver phone instead of tracking ID. Tapping any row, including claimed rows, opens details for tracking ID/manual source, destination, payment, charges, cash advance, status, note, and claim note. Remove stays in the action menu and requires confirmation before the backend call.
- Polished Gate Incoming payment display without changing backend values: UI labels show `ငွေတောင်းရန်` for `unpaid` and `ငွေရှင်းပြီး` for `paid`. Entry details now show Receiver Name as an explicit field and hide the internal Entry Type field.
- Fixed Gate Incoming existing-parcel remove semantics: removing an unclaimed existing parcel from an unpaid incoming list soft-removes the entry and rolls the parcel master status back from `arrived` to `dispatched`, allowing the tracking ID to be attached again. Manual parcel removal remains entry-only.
- Added Gate Incoming tracking-ID confirmation flow: a read-only authenticated preview RPC validates the parcel and returns receiver/payment details without changing status. Android shows those details and calls the attach RPC only after the operator presses `Confirm Attach`.
- Gate Incoming tracking-ID lookup and confirm-attach failures now use blocking error dialogs instead of transient snackbars, so operators can read why a parcel was not found or could not be attached.
- Replaced raw Supabase/PostgREST text in Gate Incoming tracking-ID dialogs with operator-friendly Myanmar messages for missing parcels, invalid lifecycle status, claimed parcels, duplicates, paid-list locks, missing lists, and gate-account access errors. Unknown failures show a retry/network-check message.
- Polished the Gate Incoming Manual Parcel dialog: grouped receiver/payment/note sections, added field icons and spacing, made amount inputs responsive on narrow screens, and added visible required/non-negative validation feedback.
- Fixed Manual Parcel dialog runtime assertions introduced during polish: removed `LayoutBuilder` from AlertDialog intrinsic sizing, kept amount inputs in a stable vertical layout, and set the multiline note field to `TextInputType.multiline`.
- Polished the Gate Incoming Driver Payment dialog to match the manual-entry form: added a payment icon and short prompt, spaced inputs, multiline optional note, visible non-negative amount validation, constrained dialog width, and an icon-backed confirm action.
- Improved printer connect preflight UX: before opening the package default `PrinterConnectPage`, the app now shows blocking dialogs for missing/blocked Bluetooth, Nearby devices, or Location permissions and for Bluetooth being turned off. Permission-blocked cases offer an App Settings button; Bluetooth-off cases tell the operator to enable Bluetooth first.

## Known Issues
- Requested Gradle Groovy files `android/app/build.gradle` and `android/build.gradle` are not present; project appears to use Kotlin DSL Gradle files.
- Manual/background sync for existing pending local parcels is not implemented by design; old local-only parcels should not be blind-synced.
- Current production APK readiness: Unknown / needs confirmation.
- Authenticated parcel RPC still needs real-device verification from the Flutter print/save flow.
- Bluetooth printer connect should be retested on a real Android device after the `pos_printer_kit` branch update; if it still returns native `connect_failed` / `result status connect: false`, next investigation should stay in package/native connection behavior without replacing the package connect UI.

## Next Tasks
- Confirm current release goal: local APK, internal testing, Play Store, or continued MVP development.
- Decide whether to create `CODEX_RULES.md` as a separate permanent rules file.
- Fix project metadata such as `pubspec.yaml` description.
- Review release signing behavior before any production APK release.
- For database changes, follow `DATABASE_NOTES.md`: update schemaVersion, add migrations, regenerate Drift code, and run tests.
- Real-device test new parcel print/save against Supabase and confirm server row, local row, printed tracking ID, and counter increments.
- Test two devices printing at the same time and confirm server tracking IDs do not duplicate.
- Test second-device login and confirm pulling down on Parcel List downloads the branch/admin-visible server parcels into local history.
- Test offline Parcel History, parcel detail, and reprint after at least one successful login/profile load and server pull.
- Verify login on a real Android device for admin, Taunggyi, Lashio, and Tachileik accounts.
- Retest login with an Auth user that has no active `staff_profiles` row and confirm it stays on the account setup/no-access view instead of reaching Home.
- Review Windows `TKT Transport Ledger` Beta 1 before depending on it operationally: Inventory and Reports are still placeholder/mock-backed areas, while Home/Main Ledger and Driver are the main Supabase-backed beta workflows.
- Create Supabase Auth users and `staff_profiles` rows for `gate_llm` and `gate_kgt`, then real-device test gate login and `LLM/KGT` voucher creation.
- Real-device test Android gate Main Ledger and Incoming Parcels with `kyaingtong@tkt.com`, including attach guards, settle locks, manual entry, claim note, and driver payment lock.

## Decisions
- Use Riverpod/provider/repository/service patterns for new work unless architecture changes are explicitly requested.
- Keep Codex changes minimal and task-focused.
- Do not refactor unrelated files.
- Do not inspect the whole project for routine tasks; inspect only relevant files.
- Do not edit generated Drift files manually; use build_runner generation.
- Never delete/drop/remove database objects or data without explicit approval. Do not run destructive SQL such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, broad `DELETE`, or destructive migration steps unless the user specifically approves the exact operation.
- Architecture, database schema, and release process changes require confirmation before broad edits.
- Supabase Auth/RLS model: staff users see their own branch, admins see all branches, one staff account may be used on two devices.
- Supabase public app tables must not grant app roles destructive table privileges such as `DELETE` or `TRUNCATE`; app access should remain minimal and RLS-scoped.
- Branch voucher header contact fields live on Supabase `branches.address` and `branches.phone_numbers`; staff update their own branch profile from Account. Local voucher header address/phone remains fallback/legacy data only.
- Town master data belongs in Supabase `towns`, not `branches`. Branches remain login/account/counter/voucher-header offices; towns are parcel route/destination choices.
- `branches.id` is a stable text integration key. Keep existing `source_tgi`, `source_lso`, and `source_tcl` IDs unchanged. Gate IDs are `gate_llm` and `gate_kgt`; no `parent_branch_id` is required.
- Android To Town choices must come from Supabase `towns` sorted by `sort_order`; do not reintroduce device-local To Town add/delete/read-only management UI in Settings.
- Android From Town choices must come from active Supabase `branches`; do not reintroduce device-local From Town management UI in Settings.
- Android gate operation tables stay separate from Windows ledger tables. Gate users may read active drivers but add/edit drivers only from Windows/Admin.
- Login success must return to the root `AuthGate`; do not navigate directly from `LoginScreen` to `HomeScreen`, because staff profile access must be checked first.
- Server-side tracking IDs must be generated by the authenticated `create_parcel_with_counter` RPC to avoid duplicate counters across devices.
- Tracking ID format is `CITY-YYMMDD-NNNN`; `CITY` is the issuing branch/account city code, not necessarily selected From Town. Do not use account code in new server-generated tracking IDs.
- `parcels.cityCode` / Supabase `parcels.city_code` stores the issuing branch city code for new official parcels. Use `fromTown` for the selected parcel origin town.
- Official voucher printing requires a server-issued tracking ID. The app should repaint the voucher with the server ID before capture/print.
- New official parcel creation remains online-only. Saved Parcel History, detail, and reprint should use local Drift data and work offline where possible.
- If save/print fails after server creation, do not delete the Supabase parcel and do not create a replacement ID. Recover by pulling Parcel History and reprinting the existing official parcel.
- Do not blind-sync old local-only printed parcels. Old printed/local-only parcels remain local history only.
- Server official tracking starts with new parcels created through `create_parcel_with_counter(...)`.
- Pull sync direction is server -> local only. It may insert/update server-created parcels on a device, but it must not upload old local-only history.
- Pull sync cursor is account-scoped and updates only after server rows are parsed and local upserts complete. If fetch/parse/upsert fails, keep the previous account cursor so the next refresh can retry the same server changes.
- Real-time sync is deferred. Prefer manual/silent pull refresh first; add realtime later only if operations need live dispatch/status updates across devices.
- Parcel History status colors are UI-only indicators; do not change database status values just to change colors. Current active filters are search text, date, and status.
- Printer connect page should remain the `pos_printer_kit` default `PrinterConnectPage`; use app permission helper before opening it.
- Printer connection retry/disconnect-before-connect logic belongs in `pos_printer_kit` core/native layer, not in a custom app connect UI.
- Release builds must use a real release keystore. Do not ship a production APK signed with the debug key.
- Never put a Supabase service-role key in Flutter source, dart defines, assets, or release scripts.
