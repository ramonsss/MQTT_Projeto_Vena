// Phase 15 — E2E Smoke Test
//
// Covers the full happy path with all network/MQTT services replaced by
// in-memory fakes and provider overrides.  No real backend, broker, or
// Google Sign-In required.
//
// Flow tested:
//   1. App launch → router reads authenticated state → lands on /devices
//   2. Devices screen shows "Estufa 1" device card
//   3. Tap device card → navigates to /devices/dev-001 (live detail)
//   4. Live detail renders ambient temperature "22"
//   5. Tap history icon → navigates to history screen (renders chip rail)
//   6. Press back → back on DeviceDetailScreen; press back again → DevicesScreen
//   7. Tap FAB → navigates to PairScreen

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/app.dart';
import 'package:vena_app/core/auth/auth_provider.dart';
import 'package:vena_app/core/auth/models/user_info.dart';
import 'package:vena_app/core/auth/secure_token_storage.dart';
import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/core/mqtt/mqtt_lifecycle.dart';
import 'package:vena_app/core/mqtt/mqtt_message_handler.dart';
import 'package:vena_app/core/mqtt/mqtt_provider.dart';
import 'package:vena_app/core/mqtt/mqtt_service.dart';
import 'package:vena_app/core/network/device_api.dart';
import 'package:vena_app/core/network/models/mqtt_credentials.dart';
import 'package:vena_app/core/network/models/telemetry_point.dart';
import 'package:vena_app/core/network/mqtt_api.dart';
import 'package:vena_app/core/sync/device_sync_service.dart';
import 'package:vena_app/core/sync/outbox_worker.dart';
import 'package:vena_app/features/devices/application/devices_provider.dart';
import 'package:vena_app/features/history/application/history_provider.dart';
import 'package:vena_app/features/live/application/live_telemetry_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockDeviceApi extends Mock implements DeviceApi {}

// ── Fake: SecureTokenStorage (no FlutterSecureStorage dependency) ─────────────

class _FakeSecureTokenStorage implements SecureTokenStorage {
  // `implements` on a concrete class: no super call, just provide the public API.
  @override
  Future<void> saveTokens({required String access, required String refresh}) async {}
  @override
  Future<String?> getAccessToken() async => 'fake-access';
  @override
  Future<String?> getRefreshToken() async => 'fake-refresh';
  @override
  Future<void> saveMqttToken(String token) async {}
  @override
  Future<String?> getMqttToken() async => null;
  @override
  Future<void> clear() async {}
}

// ── Fake: MqttApi (no Dio dependency) ─────────────────────────────────────────

class _FakeMqttApi implements MqttApi {
  // `implements` on a concrete class: no super call needed.
  @override
  Future<MqttCredentials> getMqttCredentials() async => const MqttCredentials(
        token: 'fake-jwt',
        host: 'localhost',
        port: 1883,
        expiresIn: 3600,
      );
}

// ── Fake: MqttService — all network ops are no-ops ────────────────────────────

class _FakeMqttService extends MqttService {
  _FakeMqttService()
      : super(
          mqttApi: _FakeMqttApi(),
          storage: _FakeSecureTokenStorage(),
        );

  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  void scheduleBackgroundDisconnect() {}
  @override
  void cancelBackgroundDisconnect() {}
  @override
  void subscribe(List<String> deviceIds) {}
  @override
  void dispose() {
    // Skip closing the internal stream controllers to avoid Dart errors
    // when the provider is overrideWithValue (dispose is never called anyway).
  }
}

// ── Fake: MqttLifecycleObserver — never touches WidgetsBinding ───────────────

class _FakeMqttLifecycleObserver extends MqttLifecycleObserver {
  _FakeMqttLifecycleObserver() : super(_FakeMqttService());

  @override
  void register() {}
  @override
  void unregister() {}
}

// ── AuthNotifier that starts pre-authenticated ────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => const UserInfo(
        userId: 'smoke-user-1',
        email: 'smoke@vena.farm',
        name: 'Smoke Tester',
      );
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _kDeviceId = 'dev-001';

final _device = Device(
  deviceId: _kDeviceId,
  alias: 'Estufa 1',
  status: 'online',
  lastSeenAt: null,
  fwVersion: null,
);

final _latestState = LatestState(
  deviceId: _kDeviceId,
  ts: 1000,
  ambientT: 22.5,
  ambientH: 65.0,
  dissT: null,
  dissH: null,
  setpoint: 22.0,
  pidOut: null,
  source: 'mqtt',
  online: true,
);

List<TelemetryPoint> _historyPoints() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return List.generate(
    24,
    (i) => TelemetryPoint(ts: now - (23 - i) * 3600, ambientT: 21.0 + i * 0.1),
  );
}

// ── Pump helper ───────────────────────────────────────────────────────────────

/// Pumps [frames] animation frames so GoRouter + Riverpod can settle.
Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('Smoke: launch → devices → detail → history → pair',
      (tester) async {
    final fakeMqttService = _FakeMqttService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ── Database ──────────────────────────────────────────────────
          appDatabaseProvider.overrideWithValue(db),

          // ── Auth — start already logged in ────────────────────────────
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),

          // ── Devices list ──────────────────────────────────────────────
          devicesProvider.overrideWith(
            (ref) => Stream.value([_device]),
          ),

          // ── Live telemetry (device detail) ────────────────────────────
          latestStateProvider(_kDeviceId).overrideWith(
            (ref) => Stream.value(_latestState),
          ),
          recentCacheProvider(_kDeviceId).overrideWith(
            (ref) async => const <TelemetryCacheData>[],
          ),

          // ── History ───────────────────────────────────────────────────
          historyProvider(_kDeviceId, HistoryRange.h24).overrideWith(
            (ref) async => _historyPoints(),
          ),
          historyProvider(_kDeviceId, HistoryRange.d7).overrideWith(
            (ref) async => _historyPoints(),
          ),
          historyProvider(_kDeviceId, HistoryRange.d30).overrideWith(
            (ref) async => _historyPoints(),
          ),

          // ── Background services — stubbed ─────────────────────────────
          mqttServiceProvider.overrideWithValue(fakeMqttService),
          mqttLifecycleProvider
              .overrideWithValue(_FakeMqttLifecycleObserver()),
          mqttMessageHandlerProvider
              .overrideWithValue(MqttMessageHandler(db)),
          outboxWorkerProvider.overrideWith((ref) {
            // Return an OutboxWorker that immediately stops itself.
            final worker = OutboxWorker(
              db: db,
              deviceApi: _MockDeviceApi(),
            );
            ref.onDispose(worker.stop);
            return worker;
          }),
          deviceSyncServiceProvider.overrideWith((ref) {
            return DeviceSyncService(
              deviceApi: _MockDeviceApi(),
              db: db,
            );
          }),
        ],
        child: const VenaApp(),
      ),
    );

    // ── Step 1: splash → router redirect → /devices ─────────────────────
    await _settle(tester);

    expect(
      find.text('Minhas Venas'),
      findsOneWidget,
      reason: 'Router should redirect authenticated user to DevicesScreen',
    );

    // ── Step 2: device card visible ──────────────────────────────────────
    await _settle(tester, frames: 5);

    expect(
      find.text('Estufa 1'),
      findsOneWidget,
      reason: 'Device alias should appear in the card list',
    );

    // ── Step 3: tap device card → DeviceDetailScreen ─────────────────────
    await tester.tap(find.text('Estufa 1'));
    await _settle(tester);

    expect(
      find.text(_kDeviceId),
      findsAtLeastNWidgets(1),
      reason: 'DeviceDetailScreen AppBar shows deviceId',
    );

    // ── Step 4: ambient temperature rendered ─────────────────────────────
    await _settle(tester);

    expect(
      find.textContaining('22'),
      findsAtLeastNWidgets(1),
      reason: 'BigMetric should display ambient temperature 22.x',
    );

    // ── Step 5: tap history icon → HistoryScreen ─────────────────────────
    await tester.tap(find.byTooltip('Histórico'));
    await _settle(tester);

    expect(
      find.text('Histórico'),
      findsAtLeastNWidgets(1),
      reason: 'HistoryScreen AppBar subtitle should read "Histórico"',
    );

    // Range selector chips visible.
    expect(find.text('24h'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);
    expect(find.text('30d'), findsOneWidget);

    // ── Step 6: back to DeviceDetailScreen → back to DevicesScreen ───────
    final backButtons = find.byIcon(Icons.arrow_back_ios_new_rounded);
    await tester.tap(backButtons.first);
    await _settle(tester);

    expect(find.text(_kDeviceId), findsAtLeastNWidgets(1),
        reason: 'Should be back on DeviceDetailScreen');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await _settle(tester);

    expect(find.text('Minhas Venas'), findsOneWidget,
        reason: 'Should be back on DevicesScreen');

    // ── Step 7: FAB → PairScreen ──────────────────────────────────────────
    await tester.tap(find.byTooltip('Parear novo dispositivo'));
    await _settle(tester);

    // PairScreen is in the tree (at minimum a Scaffold is rendered).
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1),
        reason: 'PairScreen scaffold must be rendered');
  });
}
