import 'package:dio/dio.dart';

import '../../env.dart';
import 'secure_token_storage.dart';

/// Dio interceptor that:
/// - Attaches `Authorization: Bearer <token>` to every request.
/// - On 401: silently refreshes the access token and retries once.
/// - On refresh failure: calls [onLogout] to clear session.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureTokenStorage storage,
    required Future<void> Function() onLogout,
  })  : _storage = storage,
        _onLogout = onLogout;

  final SecureTokenStorage _storage;
  final Future<void> Function() _onLogout;

  // Separate Dio for token refresh to avoid recursive interceptor calls.
  late final _refreshDio = Dio(
    BaseOptions(
      baseUrl: Env.backendUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    try {
      await _doRefresh();
      final token = await _storage.getAccessToken();
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $token';
      final response = await _refreshDio.fetch(opts);
      handler.resolve(response);
    } catch (_) {
      await _onLogout();
      handler.next(err);
    }
  }

  Future<void> _doRefresh() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) throw Exception('No refresh token');

    final response = await _refreshDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refresh},
    );
    final data = response.data!;
    await _storage.saveTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }
}
