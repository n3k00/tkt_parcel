# TKT Parcel

Offline-first Flutter parcel voucher app for Android.

## Run

Use the flavor-specific entrypoint when running the app.

### Dev

```powershell
flutter run --flavor dev -t lib/main_dev.dart
```

### Prod

```powershell
flutter run --flavor prod -t lib/main_prod.dart
```

### Default

```powershell
flutter run
```

`flutter run` uses [main.dart](C:\projects\Thein Kha Thu Transport System\TKT Parcel\lib\main.dart), which defaults to `prod` unless `APP_ENV` is passed with `--dart-define`.

## Build

### Dev APK

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

### Prod APK

```powershell
flutter build apk --release --flavor prod -t lib/main_prod.dart
```

## Release Signing

1. Create a release keystore:

```powershell
keytool -genkeypair -v -keystore keystores\\tkt-parcel-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tktparcel
```

2. Copy [key.properties.example](/C:/projects/Thein%20Kha%20Thu%20Transport%20System/TKT%20Parcel/android/key.properties.example) to `android/key.properties`

3. Fill in the real signing values:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=tktparcel
storeFile=../../keystores/tkt-parcel-release.jks
```

4. Keep `android/key.properties` and the keystore file private. Both are gitignored.

5. Build the signed prod APK:

```powershell
flutter build apk --release --flavor prod -t lib/main_prod.dart
```

Release builds fail if `android/key.properties` is missing, incomplete, or points to a missing keystore. Do not ship a production APK signed with the debug key.

## Supabase Configuration

The app reads Supabase config from dart defines and currently defaults to the production project used by this repository.

```powershell
flutter build apk --release --flavor prod -t lib/main_prod.dart --dart-define=SUPABASE_URL=https://bcfxcbkezjopwlgsaszb.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PROD_ANON_KEY
```

Only the public anon key belongs in the app. Never add a Supabase service-role key to Flutter source, dart defines, assets, or release scripts.

## Notes

- `dev` app name: `TKT Parcel Dev`
- `prod` app name: `TKT Parcel`
- Android dev flavor uses application id suffix `.dev`
- After major widget/config changes, prefer `Hot Restart` over `Hot Reload`
- Database safety rule: never delete/drop/remove database objects or data without explicit approval. Avoid destructive SQL such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, or broad `DELETE`.
- Official tracking IDs are server-generated only. New parcel print/save must call Supabase `create_parcel_with_counter(...)`, repaint the voucher with the returned tracking ID, save locally, then print.
- If Supabase parcel creation succeeds but local save or print fails, keep the server parcel. Refresh Parcel History and reprint the existing official tracking ID instead of deleting or recreating it.
- Tracking ID prefix is the issuing branch/account city code, not the selected From Town. Example: Lashio account printing Taunggyi From Town uses `LSO-YYMMDD-NNNN`.
- Do not blind-sync old local-only printed parcels. Old local-only parcels remain local history unless a separate legacy import plan is approved.
- Printer connection uses the default `pos_printer_kit` connect page. Open it through the app permission helper; do not replace the connect UI without explicit approval.
- `pos_printer_kit` is currently pinned to Git branch `codex/fix-printer-connection-hangs` at package path `packages/pos_printer_kit` so connection retry/disconnect-before-connect behavior stays in the package/core layer.

## Verification

```powershell
flutter analyze
flutter test
```
