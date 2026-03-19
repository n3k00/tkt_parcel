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

## Notes

- `dev` app name: `TKT Parcel Dev`
- `prod` app name: `TKT Parcel`
- Android dev flavor uses application id suffix `.dev`
- After major widget/config changes, prefer `Hot Restart` over `Hot Reload`

## Verification

```powershell
flutter analyze
flutter test
```
