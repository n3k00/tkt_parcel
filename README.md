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

If `android/key.properties` is missing, release builds currently fall back to debug signing so local testing can continue.

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
