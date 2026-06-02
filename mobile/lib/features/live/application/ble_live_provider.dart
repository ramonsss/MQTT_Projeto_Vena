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
  return ref.watch(bleServiceProvider).onTelemetry.where((t) => t.deviceId == deviceId);
}
