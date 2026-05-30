// T1 — SecureTokenStorage: write/read/clear delegates to FlutterSecureStorage.
// T2 — AuthInterceptor: attaches Bearer header on request; skips when no token.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/auth/auth_interceptor.dart';
import 'package:vena_app/core/auth/secure_token_storage.dart';

class _MockFss extends Mock implements FlutterSecureStorage {}

class _MockStorage extends Mock implements SecureTokenStorage {}

void main() {
  // ── T1: SecureTokenStorage ─────────────────────────────────────────────
  group('T1 – SecureTokenStorage', () {
    late _MockFss fss;
    late SecureTokenStorage sut;

    setUp(() {
      fss = _MockFss();
      sut = SecureTokenStorage(fss);
    });

    test('saveTokens writes to correct keys', () async {
      when(() => fss.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      await sut.saveTokens(access: 'acc123', refresh: 'ref456');

      verify(() => fss.write(key: 'vena_access_token', value: 'acc123'))
          .called(1);
      verify(() => fss.write(key: 'vena_refresh_token', value: 'ref456'))
          .called(1);
    });

    test('getAccessToken reads vena_access_token', () async {
      when(() => fss.read(key: 'vena_access_token'))
          .thenAnswer((_) async => 'stored_token');

      expect(await sut.getAccessToken(), 'stored_token');
    });

    test('getRefreshToken reads vena_refresh_token', () async {
      when(() => fss.read(key: 'vena_refresh_token'))
          .thenAnswer((_) async => 'stored_refresh');

      expect(await sut.getRefreshToken(), 'stored_refresh');
    });

    test('clear calls deleteAll on underlying storage', () async {
      when(() => fss.deleteAll()).thenAnswer((_) async {});

      await sut.clear();

      verify(() => fss.deleteAll()).called(1);
    });

    test('getAccessToken returns null when nothing stored', () async {
      when(() => fss.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      expect(await sut.getAccessToken(), isNull);
    });
  });

  // ── T2: AuthInterceptor ────────────────────────────────────────────────
  group('T2 – AuthInterceptor', () {
    late _MockStorage mockStorage;
    late AuthInterceptor interceptor;

    setUp(() {
      mockStorage = _MockStorage();
      interceptor = AuthInterceptor(
        storage: mockStorage,
        onLogout: () async {},
      );
    });

    test('onRequest attaches Authorization header when token present',
        () async {
      when(() => mockStorage.getAccessToken())
          .thenAnswer((_) async => 'my_token');

      final options = RequestOptions(path: '/test');
      interceptor.onRequest(options, RequestInterceptorHandler());
      // onRequest is async internally but returns void — allow micro-tasks to run
      await Future.delayed(Duration.zero);

      expect(options.headers['Authorization'], equals('Bearer my_token'));
    });

    test('onRequest does not set Authorization when no token', () async {
      when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);

      final options = RequestOptions(path: '/test');
      interceptor.onRequest(options, RequestInterceptorHandler());
      await Future.delayed(Duration.zero);

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('onRequest attaches header to every request independently', () async {
      when(() => mockStorage.getAccessToken())
          .thenAnswer((_) async => 'tok_abc');

      final opts1 = RequestOptions(path: '/a');
      final opts2 = RequestOptions(path: '/b');

      interceptor.onRequest(opts1, RequestInterceptorHandler());
      interceptor.onRequest(opts2, RequestInterceptorHandler());
      await Future.delayed(Duration.zero);

      expect(opts1.headers['Authorization'], 'Bearer tok_abc');
      expect(opts2.headers['Authorization'], 'Bearer tok_abc');
    });
  });
}
