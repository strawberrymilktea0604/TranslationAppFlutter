# Release Build Guide

This project has three Android flavors:

- `dev` -> `lib/main_dev.dart`
- `staging` -> `lib/main_staging.dart`
- `prod` -> `lib/main_prod.dart`

## Branding

The launcher icon and splash image are configured from:

```text
assets/branding/app_icon.png
```

Regenerate native assets after changing the image:

```powershell
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Android signing

Create a private keystore locally:

```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `android/key.properties`, then set the real passwords and alias. The app reads this file for release signing. Without `android/key.properties`, Gradle falls back to the debug signing config so CI/local release smoke builds can still run, but that output is not store-ready.

## Android release builds

```powershell
flutter build apk --release --flavor dev -t lib/main_dev.dart --obfuscate --split-debug-info=build/symbols/android/dev --split-per-abi
flutter build apk --release --flavor staging -t lib/main_staging.dart --obfuscate --split-debug-info=build/symbols/android/staging --split-per-abi
flutter build apk --release --flavor prod -t lib/main_prod.dart --obfuscate --split-debug-info=build/symbols/android/prod --split-per-abi
```

For Play Store upload, prefer an app bundle:

```powershell
flutter build appbundle --release --flavor prod -t lib/main_prod.dart --obfuscate --split-debug-info=build/symbols/android/prod
```

Keep the generated `build/symbols/...` directory for crash deobfuscation.

## GitHub Actions release builds

The workflow is:

```text
.github/workflows/build_apk.yml
```

Manual run:

1. Open GitHub -> Actions -> Frontend Release Build.
2. Choose `dev`, `staging`, or `prod`.
3. Choose Android artifact: `apk`, `appbundle`, or `both`.
4. Enable `build_ios` only when iOS signing secrets are configured.

Tag trigger:

```text
frontend-v*
```

Tag pushes build Android `prod` APK + AAB + obfuscation symbols.

Android secrets:

```text
GOOGLE_SERVICES_JSON_BASE64
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

`GOOGLE_SERVICES_JSON_BASE64` is the base64-encoded content of `android/app/google-services.json`. `ANDROID_KEYSTORE_BASE64` is the base64-encoded content of `android/app/upload-keystore.jks`. If Android keystore secrets are missing, the workflow can still smoke-build with debug signing fallback, but that output is not store-ready.

Create base64 values locally:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("frontend/android/app/upload-keystore.jks"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("frontend/android/app/google-services.json"))
```

iOS secrets:

```text
IOS_DISTRIBUTION_CERTIFICATE_BASE64
IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
IOS_PROVISIONING_PROFILE_BASE64
IOS_TEAM_ID
IOS_EXPORT_OPTIONS_PLIST_BASE64
```

`IOS_EXPORT_OPTIONS_PLIST_BASE64` is optional; when omitted, the workflow uses `ios/ExportOptions.example.plist`.

## iOS signing

On macOS with Xcode installed, copy:

```text
ios/Runner/Signing.xcconfig.example -> ios/Runner/Signing.xcconfig
ios/ExportOptions.example.plist -> ios/ExportOptions.plist
```

Then replace `YOUR_TEAM_ID` with the Apple Developer Team ID and install the matching Apple Distribution certificate plus provisioning profile in Xcode/Keychain. `ios/Flutter/Release.xcconfig` optionally includes `ios/Runner/Signing.xcconfig` when present.

## iOS release builds

Flutter iOS builds require macOS and Xcode:

```powershell
flutter build ipa -t lib/main_dev.dart --obfuscate --split-debug-info=build/symbols/ios/dev --export-options-plist=ios/ExportOptions.plist
flutter build ipa -t lib/main_staging.dart --obfuscate --split-debug-info=build/symbols/ios/staging --export-options-plist=ios/ExportOptions.plist
flutter build ipa -t lib/main_prod.dart --obfuscate --split-debug-info=build/symbols/ios/prod --export-options-plist=ios/ExportOptions.plist
```
