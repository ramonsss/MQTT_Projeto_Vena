/// Environment configuration injected via --dart-define at build time.
///
/// Android emulator (padrão — nenhuma flag necessária):
///   flutter run
///
/// Dispositivo físico (substitua pelo IP local do PC):
///   flutter run \
///     --dart-define=BACKEND_URL=http://192.168.x.x:8000 \
///     --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
///
/// Nota: o host/port MQTT não é configurado aqui. O app obtém essas
/// informações via POST /mqtt/credentials respondido pelo backend.
class Env {
  Env._();

  /// Base URL for the FastAPI backend (no trailing slash).
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Google OAuth 2.0 server client ID (web client ID from Google Cloud Console).
  /// Must be set for Google Sign-In to work on Android.
  /// Add your own: `--dart-define=GOOGLE_CLIENT_ID=YOUR_ID.apps.googleusercontent.com`
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
