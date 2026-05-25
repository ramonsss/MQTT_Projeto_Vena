import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ble/ble_models.dart';
import '../../../core/ble/ble_provider.dart';

part 'ble_live_provider.g.dart';

/// Watches BLE telemetry for a specific device and emits the latest reading.
@riverpod
Stream<BleTelemetry?> bleLiveTelemetry(
  BleLiveTelemetryRef ref,
  String deviceId,
) {
  return ref.watch(bleTelemetryProvider.stream).where((t) => t.deviceId == deviceId);
}
