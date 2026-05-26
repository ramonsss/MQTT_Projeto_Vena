// Fase 16 — BLE Provisioning E2E Smoke Test
//
// Validates the full BLE wizard UI flow end-to-end with all network and
// hardware calls replaced by in-process fakes. No real BLE adapter, camera,
// or backend server is needed.
//
// Flow:
//   1. App launches → authenticated → /devices (empty list)
//   2. Tap FAB → PairScreen (starts in `confirming` state — camera bypassed)
//   3. Verify confirming step renders device_id + "Buscar via Bluetooth"
//   4. Tap "Buscar via Bluetooth" → bleScan step: 2 fake Vena devices listed
//   5. Tap "Vena-S001" → provisioning step: Wi-Fi credentials form
//   6. Enter SSID + PSK → tap "Configurar Wi-Fi" → naming step
//   7. Verify "Dispositivo pareado!" message
//   8. Tap "Concluir" → success → router redirects to /devices
//   9. Verify "Minhas Venas" screen is rendered

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
import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/ble/ble_provider.dart';
import 'package:vena_app/core/ble/ble_service.dart';
import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/core/mqtt/mqtt_lifecycle.dart';
import 'package:vena_app/core/mqtt/mqtt_message_handler.dart';
import 'package:vena_app/core/mqtt/mqtt_provider.dart';
import 'package:vena_app/core/mqtt/mqtt_service.dart';
import 'package:vena_app/core/network/device_api.dart';
import 'package:vena_app/core/network/models/mqtt_credentials.dart';
import 'package:vena_app/core/network/mqtt_api.dart';
import 'package:vena_app/core/sync/device_sync_service.dart';
import 'package:vena_app/core/sync/outbox_worker.dart';
import 'package:vena_app/features/devices/application/devices_provider.dart';
import 'package:vena_app/features/pairing/application/pairing_provider.dart';

// ── Fakes & Mocks ─────────────────────────────────────────────────────────────

class _MockDeviceApi extends Mock implements DeviceApi {}

class _FakeSecureTokenStorage implements SecureTokenStorage {
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

class _FakeMqttApi implements MqttApi {
  @override
  Future<MqttCredentials> getMqttCredentials() async => const MqttCredentials(
        token: 'fake-jwt',
        host: 'localhost',
        port: 1883,
        expiresIn: 3600,
      );
}

class _FakeMqttService extends MqttService {
  _FakeMqttService()
      : super(mqttApi: _FakeMqttApi(), storage: _FakeSecureTokenStorage());

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
  void dispose() {}
}

class _FakeMqttLifecycleObserver extends MqttLifecycleObserver {
  _FakeMqttLifecycleObserver() : super(_FakeMqttService());

  @override
  void register() {}
  @override
  void unregister() {}
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async => const UserInfo(
        userId: 'smoke-ble-1',
        email: 'ble-smoke@vena.farm',
        name: 'BLE Smoke Tester',
      );
}

/// Minimal BLE service fake — only the methods called by reset() need to
/// be implemented. All BLE interaction goes through [_SmokePairingNotifier],
/// so the real scan/connect/provision paths are never exercised here.
class _FakeBleService extends Mock implements BleService {
  final _stateCtrl = StreamController<BleConnectionStatus>.broadcast();
  final _telemetryCtrl = StreamController<BleTelemetry>.broadcast();

  @override
  Stream<BleConnectionStatus> get connectionState => _stateCtrl.stream;

  @override
  Stream<BleTelemetry> get onTelemetry => _telemetryCtrl.stream;

  @override
  BleConnectionStatus get currentStatus => BleConnectionStatus.disconnected;

  @override
  void stopScan() {}

  @override
  Future<void> disconnectDevice() async {}

  void close() {
    _stateCtrl.close();
    _telemetryCtrl.close();
  }
}

/// Smoke-test variant of [PairingNotifier]:
///   • Starts in `confirming` state (device already identified — bypasses camera).
///   • All transition methods advance state synchronously without touching BLE
///     hardware or network. Business-logic correctness is covered by T5 / T6.
class _SmokePairingNotifier extends PairingNotifier {
  @override
  PairingState build() {
    // No BLE resources to manage — dispose is a no-op.
    ref.onDispose(() {});
    return const PairingState(
      step: PairingStep.confirming,
      deviceId: _kDeviceId,
      pairingCode: _kPairingCode,
    );
  }

  @override
  void startBleScan() {
    state = state.copyWith(
      step: PairingStep.bleScan,
      discoveredDevices: const [
        DiscoveredVenaDevice(bleId: 'fake-ble-01', name: 'Vena-S001', rssi: -55),
        DiscoveredVenaDevice(bleId: 'fake-ble-02', name: 'Vena-S002', rssi: -72),
      ],
    );
  }

  @override
  Future<void> selectDevice(String bleDeviceId, String bleDeviceName) async {
    state = state.copyWith(
      step: PairingStep.provisioning,
      selectedBleDeviceId: bleDeviceId,
      selectedBleDeviceName: bleDeviceName,
    );
  }

  @override
  Future<void> submitProvisioning(String ssid, String psk) async {
    // Skip actual BLE write + poll — jump straight to naming step.
    state = state.copyWith(step: PairingStep.naming);
  }

  @override
  Future<void> finishWithAlias(String alias) async {
    state = state.copyWith(step: PairingStep.success, alias: alias.trim());
  }
}

// ── Test constants ────────────────────────────────────────────────────────────

const _kDeviceId = 'vena-smoke-e2e';
const _kPairingCode = 'SM0K-E2E1';

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ── Test ──────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeBleService fakeBle;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeBle = _FakeBleService();
  });

  tearDown(() async {
    fakeBle.close();
    await db.close();
  });

  testWidgets(
    'BLE Provisioning Smoke: confirming → scan → provision → naming → /devices',
    (tester) async {
      final fakeMqtt = _FakeMqttService();
      final mockDeviceApi = _MockDeviceApi();

      // Stub DeviceApi calls that OutboxWorker / DeviceSyncService may make.
      when(() => mockDeviceApi.listDevices())
          .thenAnswer((_) async => const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // ── Database ────────────────────────────────────────────────
            appDatabaseProvider.overrideWithValue(db),

            // ── Auth — pre-authenticated ─────────────────────────────────
            authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),

            // ── Devices list — starts empty ──────────────────────────────
            devicesProvider.overrideWith((ref) => Stream.value(const [])),

            // ── BLE service — minimal fake ───────────────────────────────
            bleServiceProvider.overrideWithValue(fakeBle),

            // ── Pairing wizard — smoke notifier ──────────────────────────
            pairingNotifierProvider
                .overrideWith(() => _SmokePairingNotifier()),

            // ── Background services — no-ops ─────────────────────────────
            mqttServiceProvider.overrideWithValue(fakeMqtt),
            mqttLifecycleProvider
                .overrideWithValue(_FakeMqttLifecycleObserver()),
            mqttMessageHandlerProvider
                .overrideWithValue(MqttMessageHandler(db)),
            outboxWorkerProvider.overrideWith((ref) {
              final worker = OutboxWorker(db: db, deviceApi: mockDeviceApi);
              ref.onDispose(worker.stop);
              return worker;
            }),
            deviceSyncServiceProvider.overrideWith((ref) {
              return DeviceSyncService(deviceApi: mockDeviceApi, db: db);
            }),
          ],
          child: const VenaApp(),
        ),
      );

      // ── 1: router redirect → /devices ──────────────────────────────────
      await _settle(tester);
      expect(
        find.text('Minhas Venas'),
        findsOneWidget,
        reason: 'Authenticated user should land on /devices',
      );

      // ── 2: tap FAB → PairScreen ─────────────────────────────────────────
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester);

      // PairScreen opens in `confirming` state (camera step bypassed).
      // The confirming step shows the device_id + pairing_code + button.
      expect(
        find.textContaining(_kDeviceId),
        findsAtLeastNWidgets(1),
        reason: 'Confirming step must display the device_id from the QR',
      );
      expect(
        find.textContaining(_kPairingCode),
        findsAtLeastNWidgets(1),
        reason: 'Confirming step must display the pairing_code from the QR',
      );
      expect(
        find.text('Buscar via Bluetooth'),
        findsOneWidget,
        reason: '"Buscar via Bluetooth" button must be visible in confirm step',
      );

      // ── 3: tap "Buscar via Bluetooth" → bleScan step ────────────────────
      await tester.tap(find.text('Buscar via Bluetooth'));
      await _settle(tester);

      // Fake notifier immediately emits two Vena devices.
      expect(
        find.text('Vena-S001'),
        findsAtLeastNWidgets(1),
        reason: 'BleScanStep must show the first fake Vena device',
      );
      expect(
        find.text('Vena-S002'),
        findsAtLeastNWidgets(1),
        reason: 'BleScanStep must show the second fake Vena device',
      );

      // ── 4: tap "Vena-S001" → provisioning step ──────────────────────────
      await tester.tap(find.text('Vena-S001').first);
      await _settle(tester);

      // selectDevice() jumps straight to provisioning (no real connect).
      expect(
        find.text('Configurar Wi-Fi'),
        findsAtLeastNWidgets(1),
        reason: 'WifiProvisionStep heading must be visible',
      );
      expect(
        find.byType(TextFormField),
        findsAtLeastNWidgets(2),
        reason: 'SSID and PSK fields must be present',
      );

      // ── 5: fill Wi-Fi form and submit ───────────────────────────────────
      await tester.enterText(find.byType(TextFormField).at(0), 'FazendaWifi');
      await tester.enterText(find.byType(TextFormField).at(1), 'senha1234');
      // Tap the submit button (last "Configurar Wi-Fi" text avoids ambiguity
      // with the heading Text widget).
      await tester.tap(find.text('Configurar Wi-Fi').last);
      await _settle(tester, frames: 15);

      // ── 6: naming step ──────────────────────────────────────────────────
      expect(
        find.text('Dispositivo pareado!'),
        findsOneWidget,
        reason: 'PairingSuccessStep must render after provisioning succeeds',
      );

      // ── 7: enter alias and finish ───────────────────────────────────────
      await tester.enterText(find.byType(TextField), 'Minha Vena Smoke');
      await tester.tap(find.text('Concluir'));
      await _settle(tester, frames: 15);

      // ── 8: success → router redirects to /devices ──────────────────────
      // PairScreen's ref.listen fires context.go('/devices') on success.
      expect(
        find.text('Minhas Venas'),
        findsOneWidget,
        reason: 'After wizard completes, router must navigate back to /devices',
      );
    },
  );
}
