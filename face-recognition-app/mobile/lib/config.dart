/// Base URL of the backend.
///
/// Override per build: `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000`.
/// The Android emulator reaches the host machine at 10.0.2.2, which is why that is
/// the default rather than localhost.
class Config {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
