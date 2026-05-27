// Mock entry point — visualiza o design sem backend real.
//
// flutter run -t lib/main_mock.dart
//
// O que faz:
//  1. Substitui SecureTokenStorage por versão fake (token sempre presente)
//  2. Semeia o Drift com 3 devices + telemetria realista
//  3. Sobrescreve deviceApiProvider com Dio que retorna histórico sintético
//     e aceita provisioning / claim / alias
//  4. Sobrescreve bleServiceProvider com fake BLE (scan → connect → provision)
//  5. Câmera funciona de verdade — lê QR codes reais

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' show DiscoveredDevice;

import 'app.dart';
import 'core/auth/secure_token_storage.dart';
import 'core/ble/ble_models.dart';
import 'core/ble/ble_provider.dart';
import 'core/ble/ble_service.dart';
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

// ── Mock BLE Service ─────────────────────────────────────────────────────────

/// Simulates BLE scan → connect → provision without real Bluetooth.
///
/// Discovers a fake device named "Vena-35F4" (matching ESP32 MAC D0:EF:76:32:35:F4).
/// Connection succeeds immediately. provisioning writes "succeed". wifi_status
/// transitions from not-connected to connected after a short delay.
class _MockBleService implements BleService {
  final _stateCtrl = StreamController<BleConnectionStatus>.broadcast();
  final _telemetryCtrl = StreamController<BleTelemetry>.broadcast();

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  bool _provisioned = false;

  @override
  Stream<BleConnectionStatus> get connectionState => _stateCtrl.stream;

  @override
  Stream<BleTelemetry> get onTelemetry => _telemetryCtrl.stream;

  @override
  BleConnectionStatus get currentStatus => _status;

  void _emitState(BleConnectionStatus s) {
    _status = s;
    _stateCtrl.add(s);
  }

  // ── Scan ─────────────────────────────────────────────────────────────────

  @override
  void startScan({
    required void Function(DiscoveredDevice) onDeviceFound,
    Duration timeout = const Duration(seconds: 10),
  }) {
    _emitState(BleConnectionStatus.scanning);
    // startScan is not used by the pairing wizard (it uses scanForVenaDevices)
    // but we still need to implement it to satisfy the interface.
    stopScan();
  }

  @override
  Stream<DiscoveredVenaDevice> scanForVenaDevices({
    Duration timeout = const Duration(seconds: 15),
  }) {
    _emitState(BleConnectionStatus.scanning);
    return Stream.periodic(const Duration(milliseconds: 300), (i) {
      return const DiscoveredVenaDevice(
        bleId: 'D0:EF:76:32:35:F4',
        name: 'Vena-35F4',
        rssi: -42,
      );
    }).take(1).asBroadcastStream();
  }

  @override
  void stopScan() {
    if (_status == BleConnectionStatus.scanning) {
      _emitState(BleConnectionStatus.disconnected);
    }
  }

  // ── Connect ──────────────────────────────────────────────────────────────

  @override
  void connectToDevice(String bleDeviceId) {
    _emitState(BleConnectionStatus.connecting);
    // Simulate connection success after 600ms
    Future.delayed(const Duration(milliseconds: 600), () {
      _emitState(BleConnectionStatus.connected);
    });
  }

  @override
  Future<void> disconnectDevice() async {
    _provisioned = false;
    _emitState(BleConnectionStatus.disconnected);
  }

  // ── Read characteristics ─────────────────────────────────────────────────

  @override
  Future<String?> readDeviceId() async => 'vena-d0ef763235f4';

  @override
  Future<String?> readPairingCode() async => '8A4A-4AF1';

  @override
  Future<BleWifiStatus?> readWifiStatus() async {
    if (_provisioned) {
      return const BleWifiStatus(
        connected: true,
        ssid: 'MockWifi',
        ip: '192.168.1.42',
        rssi: -55,
      );
    }
    return const BleWifiStatus(connected: false);
  }

  // ── Provisioning ─────────────────────────────────────────────────────────

  @override
  Future<bool> provisionWifi(BleWifiCredentials creds) async {
    // Simulate write delay
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _provisioned = true;
    return true;
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stateCtrl.close();
    _telemetryCtrl.close();
  }
}

// ── Mock DeviceApi (synthetic history data + provisioning) ─────────────────

/// Returns 120 synthetic telemetry points for history.
/// Also handles provisioning, claim, and alias endpoints.
DeviceApi _buildMockDeviceApi() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;

        // ── History ─────────────────────────────────────────────────────────
        if (path.contains('/history')) {
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
          return;
        }

        // ── Provisioning ────────────────────────────────────────────────────
        if (path.contains('/devices/provision')) {
          handler.resolve(Response(
            requestOptions: options,
            data: {'device_jwt': 'mock-device-jwt-for-esp32'},
            statusCode: 200,
          ));
          return;
        }

        // ── Claim ───────────────────────────────────────────────────────────
        if (path.contains('/claim')) {
          handler.resolve(Response(
            requestOptions: options,
            data: {'status': 'claimed'},
            statusCode: 200,
          ));
          return;
        }

        // ── List devices ────────────────────────────────────────────────────
        if (path == '/devices' && options.method == 'GET') {
          handler.resolve(Response(
            requestOptions: options,
            data: const [],
            statusCode: 200,
          ));
          return;
        }

        // ── Update alias ────────────────────────────────────────────────────
        if (path.contains('/devices/') && options.method == 'PATCH') {
          handler.resolve(Response(
            requestOptions: options,
            data: {'status': 'updated'},
            statusCode: 200,
          ));
          return;
        }

        // ── Fallback — silently reject ──────────────────────────────────────
        handler.reject(
          DioException(
            requestOptions: options,
            message: 'mock: endpoint not available ($path)',
          ),
        );
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
        bleServiceProvider.overrideWithValue(_MockBleService()),
      ],
      child: const VenaApp(),
    ),
  );
}
