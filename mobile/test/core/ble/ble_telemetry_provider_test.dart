// T7 — bleTelemetryProvider:
//   • Emits BleTelemetry items while BLE service has a connected stream.
//   • Stops emitting after the mock stream closes.
//   • Multiple items can be emitted in sequence.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/ble/ble_provider.dart';

import 'ble_mocks.dart';

void main() {
  group('T7 – bleTelemetryProvider', () {
    test('emits telemetry items from BLE service stream', () async {
      final mockBle = MockBleService();
      addTearDown(mockBle.disposeMock);

      final container = ProviderContainer(
        overrides: [bleServiceProvider.overrideWithValue(mockBle)],
      );
      addTearDown(container.dispose);

      final emitted = <BleTelemetry>[];
      final sub = container.listen(
        bleTelemetryProvider,
        (_, next) {
          if (next.hasValue) emitted.add(next.value!);
        },
      );

      final t1 = fakeBleTelementry(deviceId: 'dev1', ambientT: 21.0);
      final t2 = fakeBleTelementry(deviceId: 'dev1', ambientT: 22.0);

      mockBle.emitTelemetry(t1);
      mockBle.emitTelemetry(t2);

      await Future<void>.delayed(Duration.zero);

      expect(emitted.length, 2);
      expect(emitted[0].ambientT, 21.0);
      expect(emitted[1].ambientT, 22.0);

      sub.close();
    });

    test('stops emitting after stream closes', () async {
      final mockBle = MockBleService();
      addTearDown(mockBle.disposeMock);

      final container = ProviderContainer(
        overrides: [bleServiceProvider.overrideWithValue(mockBle)],
      );
      addTearDown(container.dispose);

      int count = 0;
      final sub = container.listen(
        bleTelemetryProvider,
        (_, next) {
          if (next.hasValue) count++;
        },
      );

      mockBle.emitTelemetry(fakeBleTelementry());
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);

      // Closing the mock stream simulates device disconnect
      mockBle.disposeMock();
      await Future<void>.delayed(Duration.zero);

      // No further increments after stream closes
      expect(count, 1);
      sub.close();
    });
  });
}
