import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../env.dart';
import 'models/user_info.dart';
import 'secure_token_storage.dart';

class AuthRepository {
  AuthRepository(this._storage);

  final SecureTokenStorage _storage;

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: Env.googleClientId.isNotEmpty ? Env.googleClientId : null,
  );

  // Dedicated Dio without auth interceptor to avoid circular dependency.
  late final _dio = Dio(
    BaseOptions(
      baseUrl: Env.backendUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Signs in via Google, exchanges id_token with backend, stores tokens.
  Future<UserInfo> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google Sign-In cancelled');

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('No id_token received from Google');

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/google',
      data: {'id_token': idToken},
    );
    final data = response.data!;

    await _storage.saveTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );

    return UserInfo.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Refreshes tokens using the stored refresh_token.
  Future<void> refreshToken() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) throw Exception('No refresh token stored');

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refresh},
    );
    final data = response.data!;

    await _storage.saveTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  /// Clears all tokens and signs out of Google.
  Future<void> signOut() async {
    await Future.wait([
      _storage.clear(),
      _googleSignIn.signOut(),
    ]);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(secureTokenStorageProvider));
});
