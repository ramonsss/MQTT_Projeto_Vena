// Mock entry point — visualiza o design sem backend real.
//
// flutter run -t lib/main_mock.dart
//
// O que faz:
//  1. Substitui SecureTokenStorage por versão fake (token sempre presente)
//     → AuthNotifier.build() acha o token e restaura o UserInfo do Drift
//  2. Semeia o Drift com 3 devices + telemetria realista
//  3. Sync / MQTT falham silenciosamente (try/catch em _postLoginSetup)

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/auth/secure_token_storage.dart';
import 'core/db/app_database.dart';

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

  // ── Device 1 — online com telemetria ──────────────────────────────────────
  await db.deviceDao.upsertDevice(DevicesCompanion(
    deviceId: const Value('vena-a1b2c3'),
    alias: const Value('Aquário Principal'),
    status: const Value('online'),
    lastSeenAt: Value(now),
    fwVersion: const Value('1.3.0'),
  ));
  await db.telemetryDao.upsertLatestState(LatestStatesCompanion(
    deviceId: const Value('vena-a1b2c3'),
    ts: Value(now),
    ambientT: const Value(24.3),
    ambientH: const Value(68.5),
    dissT: const Value(22.1),
    dissH: const Value(72.0),
    setpoint: const Value(23.0),
    pidOut: const Value(14.2),
    online: const Value(true),
  ));
  // Ring buffer com 30 pontos para o mini-chart
  for (var i = 30; i >= 0; i--) {
    final ts = now - i * 60 * 1000;
    await db.telemetryDao.insertTelemetryCache(TelemetryCacheCompanion(
      deviceId: const Value('vena-a1b2c3'),
      ts: Value(ts),
      ambientT: Value(24.3 + (i % 5) * 0.3 - 0.6),
      ambientH: Value(68.5 + (i % 3) * 1.2 - 1.2),
      dissT: Value(22.1 + (i % 4) * 0.2),
      dissH: Value(72.0 - (i % 5) * 0.5),
    ));
  }

  // ── Device 2 — offline ────────────────────────────────────────────────────
  await db.deviceDao.upsertDevice(DevicesCompanion(
    deviceId: const Value('vena-d4e5f6'),
    alias: const Value('Tanque Lateral'),
    status: const Value('offline'),
    lastSeenAt: Value(now - 2 * 60 * 60 * 1000), // 2h atrás
    fwVersion: const Value('1.2.1'),
  ));
  await db.telemetryDao.upsertLatestState(LatestStatesCompanion(
    deviceId: const Value('vena-d4e5f6'),
    ts: Value(now - 2 * 60 * 60 * 1000),
    ambientT: const Value(21.8),
    ambientH: const Value(61.0),
    dissT: const Value(20.5),
    dissH: const Value(65.0),
    setpoint: const Value(22.0),
    pidOut: const Value(0.0),
    online: const Value(false),
  ));

  // ── Device 3 — recém pareado, sem telemetria ainda ───────────────────────
  await db.deviceDao.upsertDevice(DevicesCompanion(
    deviceId: const Value('vena-g7h8i9'),
    alias: const Value(''),
    status: const Value('offline'),
  ));
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
      ],
      child: const VenaApp(),
    ),
  );
}
