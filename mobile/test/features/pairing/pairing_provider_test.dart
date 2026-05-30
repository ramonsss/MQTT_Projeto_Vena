// T6 — PairingNotifier state machine:
//   • idle → confirming (valid QR URI + JSON)
//   • idle → error (invalid QR)
//   • confirming → bleScan (startBleScan)
//   • bleScan: accumulates discovered devices sorted by RSSI
//   • bleScan → error on scan stream error
//   • reset() returns to idle

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/ble/ble_provider.dart';
import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/core/sync/device_sync_service.dart';
import 'package:vena_app/features/devices/application/device_actions_provider.dart';
import 'package:vena_app/features/pairing/application/pairing_provider.dart';
import 'package:vena_app/features/pairing/application/provisioning_service.dart';

import '../../core/ble/ble_mocks.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockDeviceActions extends Mock implements DeviceActions {}

class _MockDeviceSyncService extends Mock implements DeviceSyncService {}

class _MockProvisioningService extends Mock implements ProvisioningService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

// ── Helpers ───────────────────────────────────────────────────────────────────

DiscoveredVenaDevice _device(String id, int rssi) =>
    DiscoveredVenaDevice(bleId: id, name: 'Vena-$id', rssi: rssi);

ProviderContainer _makeContainer(MockBleService mockBle) {
  final mockActions = _MockDeviceActions();
  final mockSync = _MockDeviceSyncService();
  final mockProvisioning = _MockProvisioningService();
  final mockDb = _MockAppDatabase();

  // Stub methods that may be called by the notifier's onDispose
  when(() => mockBle.stopScan()).thenReturn(null);
  when(() => mockBle.disconnectDevice()).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      bleServiceProvider.overrideWithValue(mockBle),
      deviceActionsProvider.overrideWith(() => mockActions),
      deviceSyncServiceProvider.overrideWithValue(mockSync),
      provisioningServiceProvider.overrideWithValue(mockProvisioning),
      appDatabaseProvider.overrideWithValue(mockDb),
    ],
  );
  // Keep pairingNotifierProvider alive across async awaits (prevent auto-dispose).
  container.listen<PairingState>(pairingNotifierProvider, (_, __) {}, fireImmediately: false);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockBleService mockBle;

  setUp(() => mockBle = MockBleService());
  tearDown(() => mockBle.disposeMock());

  group('T6 – PairingNotifier state machine', () {
    // ── QR parsing ────────────────────────────────────────────────────────

    test('idle → confirming on valid vena:// URI', () {
      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);

      container
          .read(pairingNotifierProvider.notifier)
          .onQrDetected('vena://vena-abc1?code=A1B2C3D4');

      final state = container.read(pairingNotifierProvider);
      expect(state.step, PairingStep.confirming);
      expect(state.deviceId, 'vena-abc1');
      expect(state.pairingCode, 'A1B2C3D4');
    });

    test('idle → confirming on valid JSON QR', () {
      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);

      container
          .read(pairingNotifierProvider.notifier)
          .onQrDetected('{"device_id":"vena-xyz","pairing_code":"XY123456"}');

      final state = container.read(pairingNotifierProvider);
      expect(state.step, PairingStep.confirming);
      expect(state.deviceId, 'vena-xyz');
      expect(state.pairingCode, 'XY123456');
    });

    test('idle → error on invalid QR payload', () {
      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);

      container.read(pairingNotifierProvider.notifier).onQrDetected('garbage');

      final state = container.read(pairingNotifierProvider);
      expect(state.step, PairingStep.error);
      expect(state.errorMessage, isNotNull);
    });

    test('onQrDetected is a no-op when not in idle step', () {
      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);

      final notifier = container.read(pairingNotifierProvider.notifier);
      notifier.onQrDetected('vena://vena-abc1?code=A1B2C3D4');
      expect(container.read(pairingNotifierProvider).step, PairingStep.confirming);

      // Second call while in confirming — should not change state
      notifier.onQrDetected('vena://vena-other?code=OTHER1');
      final state = container.read(pairingNotifierProvider);
      expect(state.deviceId, 'vena-abc1'); // unchanged
    });

    // ── BLE scan ──────────────────────────────────────────────────────────

    test('startBleScan → bleScan step, discovers and sorts devices by RSSI',
        () async {
      final controller = StreamController<DiscoveredVenaDevice>.broadcast();
      when(() => mockBle.scanForVenaDevices(timeout: any(named: 'timeout')))
          .thenAnswer((_) => controller.stream);
      when(() => mockBle.stopScan()).thenReturn(null);

      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);
      addTearDown(controller.close);

      container.read(pairingNotifierProvider.notifier).startBleScan();
      expect(container.read(pairingNotifierProvider).step, PairingStep.bleScan);

      // Emit two devices out-of-order by RSSI
      controller.add(_device('aa', -80));
      controller.add(_device('bb', -50));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(pairingNotifierProvider);
      expect(state.discoveredDevices.length, 2);
      // Strongest signal first (higher RSSI = closer)
      expect(state.discoveredDevices.first.bleId, 'bb');
      expect(state.discoveredDevices.last.bleId, 'aa');
    });

    test('scan stream error → error step', () async {
      final controller = StreamController<DiscoveredVenaDevice>.broadcast();
      when(() => mockBle.scanForVenaDevices(timeout: any(named: 'timeout')))
          .thenAnswer((_) => controller.stream);
      when(() => mockBle.stopScan()).thenReturn(null);

      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);
      addTearDown(controller.close);

      container.read(pairingNotifierProvider.notifier).startBleScan();
      controller.addError(Exception('BLE scan failed'));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(pairingNotifierProvider).step, PairingStep.error);
    });

    // ── Reset ─────────────────────────────────────────────────────────────

    test('reset() returns to idle regardless of current step', () {
      final container = _makeContainer(mockBle);
      addTearDown(container.dispose);

      final notifier = container.read(pairingNotifierProvider.notifier);
      notifier.onQrDetected('vena://vena-abc1?code=A1B2C3D4');
      expect(container.read(pairingNotifierProvider).step, PairingStep.confirming);

      notifier.reset();
      final state = container.read(pairingNotifierProvider);
      expect(state.step, PairingStep.idle);
      expect(state.deviceId, isNull);
      expect(state.pairingCode, isNull);
      expect(state.discoveredDevices, isEmpty);
    });
  });
}
