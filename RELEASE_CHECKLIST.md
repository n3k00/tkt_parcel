# Release Checklist

## MVP Scope
- Android counter app for staff parcel voucher creation.
- Staff login through Supabase Auth and active `staff_profiles`.
- Official tracking ID comes only from Supabase `create_parcel_with_counter(...)`.
- Voucher print flow repaints with the server tracking ID before printing.
- Parcel History supports server-to-local pull refresh and local search.
- Branch contact address/phone is managed from Account / Branch Profile.

## Pre-Release Code Checks
- Run `flutter analyze`.
- Run `flutter test`.
- Confirm `pubspec.yaml` description/version/build number are release-ready.
- Confirm release signing uses a real release keystore and does not fall back to debug signing.
- Confirm app flavor and Supabase dart defines point to the correct project.
- Confirm no debug-only credentials or service-role keys are included in the app.

## Supabase Checks
- Confirm project: `tkt-transport-system` / `bcfxcbkezjopwlgsaszb`.
- Confirm required branches exist with correct `city_code`, town name, address, and phone numbers.
- Confirm staff Auth users exist and each active staff user has a matching `staff_profiles` row.
- Confirm branch staff can only see/create their own branch parcels.
- Confirm admin can see all branch parcels.
- Confirm `create_parcel_with_counter(...)` returns `CITY-YYMMDD-NNNN`.
- Confirm counters are scoped by `city_code + service_date`.
- Confirm `anon` has no table privileges on app backend tables.
- Confirm `authenticated` does not have destructive table privileges such as `DELETE` or `TRUNCATE`.
- Confirm no destructive SQL is used during release checks.

## Device Login Checks
- Login as Taunggyi staff and confirm Home opens.
- Login as Lashio staff and confirm Home opens.
- Login as Tachileik staff and confirm Home opens.
- Login as admin and confirm account access is valid.
- Login with a user that has no active `staff_profiles` row and confirm Home is blocked.
- Sign out and login as a different branch on the same device; confirm cached parcels from the previous branch are not shown.

## Parcel Creation Checks
- Create and print a parcel from each branch account.
- Confirm the printed voucher tracking ID matches the Supabase row tracking ID.
- Confirm tracking prefix uses issuing branch city code, not selected `fromTown`.
- Confirm two devices using the same account can print without duplicate tracking IDs.
- Confirm server-created parcel is saved locally after successful print/save flow.
- If physical print fails after server creation, confirm Parcel History refresh can find the official parcel for reprint.

## Parcel History Checks
- Pull down on Parcel History and confirm server parcels sync into local history.
- Confirm incremental pull sync fetches new server rows after first sync.
- Search by tracking ID.
- Search by receiver name.
- Search by receiver phone, including partial last digits.
- Confirm search field keeps focus when no rows match.
- Confirm branch staff only sees their own branch parcels.
- Confirm admin sees all visible branch parcels.

## Branch Profile Checks
- Open Account / Branch Profile and confirm address/phone load from server.
- Confirm `Last loaded from server` status is shown.
- Refresh branch profile and confirm success message.
- Save branch address/phone and confirm `Branch profile saved and refreshed`.
- Print a voucher and confirm header uses branch address/phone.

## Printer Checks
- Confirm Android Bluetooth/Nearby permissions are granted.
- Open printer connect page through the package default connect page.
- Scan and connect to the target printer.
- Print a test label/settings sample if needed.
- Print a real voucher and confirm Myanmar text, QR, tracking ID, and layout are readable.
- If connect fails, retest at the package/core layer; do not replace the default connect UI without approval.

## Build Checks
Run dev APK for internal testing:

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

Run prod APK when release config is confirmed:

```powershell
flutter build apk --release --flavor prod -t lib/main_prod.dart --dart-define=SUPABASE_URL=https://bcfxcbkezjopwlgsaszb.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PROD_ANON_KEY
```

## Go / No-Go
Release is blocked if any of these fail:

- Authenticated staff cannot login.
- Staff can see another branch's parcels.
- Official tracking IDs duplicate across devices.
- Printed voucher tracking ID differs from the Supabase tracking ID.
- Parcel History cannot recover/reprint a server-created parcel after print failure.
- Printer cannot reliably connect on the target Android device.
- Release APK uses wrong Supabase project or wrong signing configuration.
