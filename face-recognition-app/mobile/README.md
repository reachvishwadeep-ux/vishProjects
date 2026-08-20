# Flutter client

Three screens: **Identify** (upload a photo, see ranked matches), **Enrol** (add a
photo to the repository) and **Repository** (browse and delete people).

## Run

```bash
cd mobile
flutter pub get

# Android emulator reaches the host at 10.0.2.2 (this is the default)
flutter run

# physical device or iOS simulator: point at your machine's LAN address
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
```

Release builds:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com  # needs macOS + Xcode
```

## Notes

- Photos are downscaled to 1280px / JPEG q85 before upload; the model only ever sees
  a 112x112 aligned crop, so this costs no accuracy and saves 5-10x bandwidth.
- The `API_BASE_URL` default is plain HTTP for local development. Android blocks
  cleartext traffic in release builds and iOS requires an ATS exception — use HTTPS
  for anything real rather than relaxing those defaults.
- Every result shows its similarity score and the match/review/no_match decision.
  Do not present the top hit as a certainty.
