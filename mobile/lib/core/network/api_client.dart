import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../env.dart';
import '../auth/auth_interceptor.dart';
import '../auth/auth_provider.dart';
import '../auth/secure_token_storage.dart';

/// Authenticated Dio client — use this for all REST calls that require a JWT.
///
/// On 401 the [AuthInterceptor] transparently refreshes the token and retries.
/// On refresh failure it clears the session (invalidates [authNotifierProvider]).
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureTokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.backendUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      onLogout: () async {
        await storage.clear();
        ref.invalidate(authNotifierProvider);
      },
    ),
  );

  return dio;
});
