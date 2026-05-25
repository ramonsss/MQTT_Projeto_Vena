// Mock entry point — visualiza o design sem backend real.
//
// flutter run -t lib/main_mock.dart
//
// O que faz:
//  1. Substitui SecureTokenStorage por versão fake (token sempre presente)
//  2. Semeia o Drift com 3 devices + telemetria realista
//  3. Sobrescreve deviceApiProvider com Dio que retorna histórico sintético
//  4. Sync / MQTT falham silenciosamente (try/catch em _postLoginSetup)

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/auth/secure_token_storage.dart';
import 'core/db/app_database.dart';
import 'core/network/device_api.dart';

// ── Fake token storage ───────────────────────────────────────────────────────

class _MockSecureStorage extends SecureTokenStorage {
  _MockSecureStorage()
      : super(const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ));

  @override
  Future<String?> getAccessToken() async => 'mock-access-token';

  @override
  Future<String?> getRefreshToken() async => 'mock-refresh-token';
}

// ── Seed data ────────────────────────────────────────────────────────────────

Future<void> _seedDatabase(AppDatabase db) async {
  // UserSession → AuthNotifier usa isso para reconstruir o UserInfo.
  for (final e in const {
    'user_id': 'mock-user-001',
    'user_email': 'dev@vena.farm',
    'user_name': 'Dev Mode',
  }.entries) {
    await db.into(db.userSession).insertOnConflictUpdate(
      UserSessionCompanion.insert(key: e.key, value: e.value),
    );
  }

  final now = DateTime.now().millisecondsSinceEpoch;

  // ── Device 1 — online, delta +1.3°C → DeviationIndicator amarelo ──────────
  await db.deviceDao.upsertDevice(DevicesCompanion(
    deviceId: const Value('vena-a1b2c3'),
    alias: const Value('Câmara Fria A'),
    status: const Value('online'),
    lastSeenAt: Value(now),
    fwVersion: const Value('1.3.0'),
  ));
  await db.telemetryDao.upsertLatestState(LatestStatesCompanion(
    deviceId: const Value('vena-a1b2c3'),
    ts: Value(now),
    ambientT: const Value(24.3),  // delta = +1.3°C → amarelo
    ambientH: const Value(72.0),
    dissT: const Value(22.1),
    dissH: const Value(74.0),
    setpoint: const Value(23.0),
    pidOut: const Value(14.2),
    online: const Value(true),
  ));
  // Ring buffer com 60 pontos — umidade oscila ±12% para eixo secundário visível
  for (var i = 60; i >= 0; i--) {
    final ts = now - i * 60 * 1000;
    final phase = i / 60.0 * 2 * 3.14159;
    await db.telemetryDao.insertTelemetryCache(TelemetryCacheCompanion(
      deviceId: const Value('vena-a1b2c3'),
      ts: Value(ts),
      ambientT: Value(24.3 + (i % 5) * 0.3 - 0.6),
      ambientH: Value(72.0 + 10.0 * (phase % 1.0 < 0.5 ? phase % 1.0 : 1.0 - phase % 1.0) - 2.0),
      dissT: Value(22.1 + (i % 4) * 0.2),
      dissH: Value(74.0 - (i % 5) * 0.4),
    ));
  }

  // ── Device 2 — offline, delta −4.2°C → DeviationIndicator vermelho ─────────
  await db.deviceDao.upsertDevice(DevicesCompanion(
    deviceId: const Value('vena-d4e5f6'),
    alias: const Value('Câmara Fria B'),
    status: const Value('offline'),
    lastSeenAt: Value(now - 2 * 60 * 60 * 1000), // 2h atrás
    fwVersion: const Value('1.2.1'),
  ));
  await db.telemetryDao.upsertLatestState(LatestStatesCompanion(
    deviceId: const Value('vena-d4e5f6'),
    ts: Value(now - 2 * 60 * 60 * 1000),
    ambientT: const Value(18.8),  // delta = −4.2°C → vermelho
    ambientH: const Value(55.0),
    dissT: const Value(17.5),
    dissH: const Value(58.0),
    setpoint: const Value(23.0),
    pidOut: const Value(0.0),
    online: const Value(false),
  ));
  // Ring buffer para o mini-chart do device 2
  for (var i = 60; i >= 0; i--) {
    final ts = now - 2 * 60 * 60 * 1000 - i * 60 * 1000;
    await db.telemetryDao.insertTelemetryCache(TelemetryCacheCompanion(
      deviceId: const Value('vena-d4e5f6'),
      ts: Value(ts),
      ambientT: Value(18.8 - (i % 6) * 0.2 + 0.4),
      ambientH: Value(55.0 + (i % 7) * 1.5 - 2.0),
      dissT: Value(17.5 - (i % 5) * 0.15),
      dissH: Value(58.0 + (i % 3) * 0.6),
    ));
  }

  // ── Device 3 — online, delta +0.4°C → DeviationIndicator verde ───────────
  await db.deviceDao.upsertDevice(DevicesCompanion(
    deviceId: const Value('vena-g7h8i9'),
    alias: const Value('Estufa Leste'),
    status: const Value('online'),
    lastSeenAt: Value(now),
    fwVersion: const Value('1.3.1'),
  ));
  await db.telemetryDao.upsertLatestState(LatestStatesCompanion(
    deviceId: const Value('vena-g7h8i9'),
    ts: Value(now),
    ambientT: const Value(23.4),  // delta = +0.4°C → verde
    ambientH: const Value(80.5),
    dissT: const Value(22.8),
    dissH: const Value(82.0),
    setpoint: const Value(23.0),
    pidOut: const Value(4.5),
    online: const Value(true),
  ));
  // Ring buffer para o mini-chart do device 3
  for (var i = 60; i >= 0; i--) {
    final ts = now - i * 60 * 1000;
    await db.telemetryDao.insertTelemetryCache(TelemetryCacheCompanion(
      deviceId: const Value('vena-g7h8i9'),
      ts: Value(ts),
      ambientT: Value(23.4 + (i % 4) * 0.15 - 0.3),
      ambientH: Value(80.5 + (i % 5) * 2.0 - 3.5),
      dissT: Value(22.8 + (i % 3) * 0.1),
      dissH: Value(82.0 - (i % 4) * 0.3),
    ));
  }
}

// ── Mock DeviceApi (synthetic history data) ────────────────────────────────

/// Returns 120 synthetic telemetry points spread over the last 24 hours.
/// Real API calls (listDevices, claimDevice, etc.) throw silently — that's
/// fine because _postLoginSetup wraps them in try/catch.
DeviceApi _buildMockDeviceApi() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/history')) {
          final nowSec =
              DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final points = List.generate(120, (i) {
            final ts = nowSec - (119 - i) * 720; // ~24h, one point/12min
            return {
              'ts': ts,
              'ambient_t': 24.0 + (i % 9) * 0.25 - 1.0,
              'ambient_h': 67.0 + (i % 7) * 0.8 - 2.8,
              'diss_t': 22.0 + (i % 6) * 0.2 - 0.6,
              'diss_h': 71.0 + (i % 5) * 0.4,
              'setpoint': 23.0,
              'pid_out': 10.0 + (i % 8) * 1.5,
            };
          });
          handler.resolve(Response(
            requestOptions: options,
            data: points,
            statusCode: 200,
          ));
        } else {
          // Reject other calls — _postLoginSetup handles errors gracefully.
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'mock: endpoint not available',
            ),
          );
        }
      },
    ),
  );
  return DeviceApi(dio);
}

// ── Entry point ──────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  await _seedDatabase(db);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureTokenStorageProvider
            .overrideWithValue(_MockSecureStorage()),
        deviceApiProvider.overrideWithValue(_buildMockDeviceApi()),
      ],
      child: const VenaApp(),
    ),
  );
}
