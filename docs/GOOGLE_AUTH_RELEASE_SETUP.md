# Google Auth Release Setup

Planora Android release builds use package name `com.planora.mobile`.

For Google sign-in to work in debug, release APK, Firebase App Distribution, and later Play builds:

1. In Firebase or Google Cloud, add SHA-1 and SHA-256 fingerprints for the debug keystore.
2. Add SHA-1 and SHA-256 fingerprints for the release/upload key used to sign distributed APKs.
3. If Play App Signing is enabled later, add the Play app-signing SHA-1 and SHA-256 fingerprints too.
4. Download the updated `google-services.json` after adding fingerprints and replace `android/app/google-services.json`.
5. Keep backend `GOOGLE_CLIENT_ID` set to the Web OAuth client ID, not the Android OAuth client ID.

Useful commands:

```powershell
cd C:\Users\Ibrahim\Documents\Planora\mobile
flutter clean
flutter pub get
flutter build apk --release
firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app <FIREBASE_ANDROID_APP_ID> --groups <TESTER_GROUP>
```
