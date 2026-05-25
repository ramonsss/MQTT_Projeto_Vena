import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ble_models.dart';
import 'ble_service.dart';

part 'ble_provider.g.dart';

/// Singleton [BleService] — kept alive for the app session.
@Riverpod(keepAlive: true)
BleService bleService(BleServiceRef ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
}

/// Stream of BLE connection status.
@riverpod
Stream<BleConnectionStatus> bleStatus(BleStatusRef ref) {
  return ref.watch(bleServiceProvider).connectionState;
}

/// Stream of BLE telemetry.
@riverpod
Stream<BleTelemetry> bleTelemetry(BleTelemetryRef ref) {
  return ref.watch(bleServiceProvider).onTelemetry;
}
