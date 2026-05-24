/// Environment configuration injected via --dart-define at build time.
///
/// Physical Android 9 device (replace with LAN IP):
///   flutter run --dart-define=BACKEND_URL=http://192.168.1.x:8000
///               --dart-define=MQTT_HOST=192.168.1.x
///
/// Android emulator (defaults work, no flags needed):
///   flutter run
class Env {
  Env._();

  /// Base URL for the FastAPI backend (no trailing slash).
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// MQTT broker hostname.
  static const String mqttHost = String.fromEnvironment(
    'MQTT_HOST',
    defaultValue: '10.0.2.2',
  );

  /// MQTT broker port (plain TCP).
  static const int mqttPort = int.fromEnvironment(
    'MQTT_PORT',
    defaultValue: 1883,
  );

  /// Google OAuth 2.0 server client ID (web client ID from Google Cloud Console).
  /// Must be set for Google Sign-In to work on Android.
  /// Add your own: `--dart-define=GOOGLE_CLIENT_ID=YOUR_ID.apps.googleusercontent.com`
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
