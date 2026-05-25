import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/ble/ble_models.dart';

import 'ble_mocks.dart';

void main() {
  late MockBleService mockService;

  setUp(() {
    mockService = MockBleService();
  });

  tearDown(() {
    mockService.disposeMock();
  });

  group('BleService – connection states', () {
    test('emits scanning then disconnected on scan timeout', () async {
      final states = <BleConnectionStatus>[];
      final sub = mockService.connectionState.listen(states.add);

      mockService.emitState(BleConnectionStatus.scanning);
      mockService.emitState(BleConnectionStatus.disconnected);

      await Future<void>.delayed(Duration.zero);
      expect(states, [
        BleConnectionStatus.scanning,
        BleConnectionStatus.disconnected,
      ]);

      await sub.cancel();
    });

    test('emits connecting then connected on successful connection', () async {
      final states = <BleConnectionStatus>[];
      final sub = mockService.connectionState.listen(states.add);

      mockService.emitState(BleConnectionStatus.connecting);
      mockService.emitState(BleConnectionStatus.connected);

      await Future<void>.delayed(Duration.zero);
      expect(states, [
        BleConnectionStatus.connecting,
        BleConnectionStatus.connected,
      ]);

      await sub.cancel();
    });
  });

  group('BleService – telemetry stream', () {
    test('emits parsed telemetry', () async {
      final readings = <BleTelemetry>[];
      final sub = mockService.onTelemetry.listen(readings.add);

      final t = fakeBleTelementry(ambientT: 23.1, ambientH: 55.0);
      mockService.emitTelemetry(t);

      await Future<void>.delayed(Duration.zero);
      expect(readings.length, 1);
      expect(readings.first.ambientT, 23.1);
      expect(readings.first.ambientH, 55.0);

      await sub.cancel();
    });
  });

  group('BleService – permissions', () {
    test('requestPermissions returns true when granted', () async {
      final handler = MockBlePermissionHandler();
      when(() => handler.requestPermissions()).thenAnswer((_) async => true);
      when(() => handler.hasPermissions()).thenAnswer((_) async => true);

      expect(await handler.requestPermissions(), isTrue);
      expect(await handler.hasPermissions(), isTrue);
    });

    test('requestPermissions returns false when denied', () async {
      final handler = MockBlePermissionHandler();
      when(() => handler.requestPermissions()).thenAnswer((_) async => false);

      expect(await handler.requestPermissions(), isFalse);
    });
  });

  group('BleService – provisioning', () {
    test('provisionWifi calls service', () async {
      when(() => mockService.provisionWifi(fakeBleWifiCredentials))
          .thenAnswer((_) async => true);

      final result = await mockService.provisionWifi(fakeBleWifiCredentials);
      expect(result, isTrue);
      verify(() => mockService.provisionWifi(fakeBleWifiCredentials)).called(1);
    });

    test('readDeviceId returns device_id', () async {
      when(() => mockService.readDeviceId())
          .thenAnswer((_) async => 'vena-abc123');

      final id = await mockService.readDeviceId();
      expect(id, 'vena-abc123');
    });

    test('readPairingCode returns code', () async {
      when(() => mockService.readPairingCode())
          .thenAnswer((_) async => 'A1B2C3');

      final code = await mockService.readPairingCode();
      expect(code, 'A1B2C3');
    });
  });
}
