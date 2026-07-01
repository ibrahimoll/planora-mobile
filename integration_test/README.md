# Planora mobile smoke test

The smoke test uses a real Planora test account. Keep its credentials out of
source control and pass them as Dart defines:

```sh
flutter test integration_test/app_smoke_test.dart -d emulator-5554 \
  --dart-define=PLANORA_TEST_EMAIL=test-user@example.com \
  --dart-define=PLANORA_TEST_PASSWORD=replace-with-test-password
```

Run the command with an Android emulator, iOS simulator, or physical device
available, replacing `emulator-5554` with its ID from `flutter devices`. To
target a test backend, append:

```sh
--dart-define=PLANORA_API_URL=https://your-test-api.example.com
```

The account may have no projects or tasks. In that case, the corresponding
optional detail step is skipped. The test clears any existing session before
launch and logs out when it finishes.
