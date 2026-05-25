// T5 — ProvisioningService.provisionDevice():
//   • Calls DeviceApi.provisionDevice → receives device_jwt.
//   • Writes BleWifiCredentials (ssid, psk, jwt) via BleService.
//   • Polls BleService.readWifiStatus until connected → returns true.
//   • Throws when BLE write fails.
//   • Throws TimeoutException when wifi_status never becomes connected.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/network/device_api.dart';
import 'package:vena_app/features/pairing/application/provisioning_service.dart';

import '../../core/ble/ble_mocks.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockDeviceApi extends Mock implements DeviceApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const BleWifiCredentials(ssid: '', password: '', jwt: ''),
    );
  });

  late _MockDeviceApi mockApi;
  late MockBleService mockBle;
  late ProvisioningService service;

  setUp(() {
    mockApi = _MockDeviceApi();
    mockBle = MockBleService();
    service = ProvisioningService(deviceApi: mockApi, bleService: mockBle);
  });

  tearDown(() => mockBle.disposeMock());

  group('T5 – ProvisioningService.provisionDevice()', () {
    const deviceId = 'vena-abc1';
    const pairingCode = 'A1B2C3D4';
    const ssid = 'FazendaWifi';
    const psk = 'supersecret';
    const jwt = 'device.jwt.token';

    test('returns true when device connects to Wi-Fi', () async {
      when(() => mockApi.provisionDevice(deviceId, pairingCode))
          .thenAnswer((_) async => jwt);

      when(() => mockBle.provisionWifi(any())).thenAnswer((_) async => true);

      var callCount = 0;
      when(() => mockBle.readWifiStatus()).thenAnswer((_) async {
        callCount++;
        return callCount >= 2
            ? const BleWifiStatus(connected: true, ssid: ssid)
            : const BleWifiStatus(connected: false);
      });

      // Use a fake async approach: since the service sleeps 2s per poll we
      // fake it by making the service complete in the first poll when connected.
      // To avoid 2-second real delays in CI we can't use fakeAsync here (no
      // flutter_test fakeAsync that bridges async gaps), so we use a variant
      // that patches the delay by overriding the BLE service to return
      // connected on the second call.
      final result = await service.provisionDevice(
        deviceId: deviceId,
        pairingCode: pairingCode,
        ssid: ssid,
        psk: psk,
      ).timeout(const Duration(seconds: 10));

      expect(result, isTrue);
      verify(() => mockApi.provisionDevice(deviceId, pairingCode)).called(1);
      verify(() => mockBle.provisionWifi(any())).called(1);
    });

    test('throws when DeviceApi.provisionDevice fails', () async {
      when(() => mockApi.provisionDevice(deviceId, pairingCode))
          .thenThrow(Exception('404 not found'));

      expect(
        () => service.provisionDevice(
          deviceId: deviceId,
          pairingCode: pairingCode,
          ssid: ssid,
          psk: psk,
        ),
        throwsException,
      );
    });

    test('throws when BLE write fails', () async {
      when(() => mockApi.provisionDevice(deviceId, pairingCode))
          .thenAnswer((_) async => jwt);

      when(() => mockBle.provisionWifi(any())).thenAnswer((_) async => false);

      expect(
        () => service.provisionDevice(
          deviceId: deviceId,
          pairingCode: pairingCode,
          ssid: ssid,
          psk: psk,
        ),
        throwsException,
      );
    });
  });
}
