// I3 — Devices providers
//
// devicesProvider  : Stream<List<Device>>  — all devices from Drift.
// latestStateProvider : Stream<LatestState?> — single-device live state.
//
// Both providers are pure Drift streams; the UI never touches the network
// directly. MQTT and REST feed Drift; Drift feeds Riverpod; Riverpod feeds UI.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';

part 'devices_provider.g.dart';

/// Stream of all devices stored in Drift, re-emits on every table change.
///
/// Devices are inserted / updated by [DeviceSyncService] (REST) and by
/// [MqttMessageHandler] (status messages). Pull-to-refresh in
/// [DevicesScreen] triggers a manual sync.
@riverpod
Stream<List<Device>> devices(DevicesRef ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.deviceDao.watchAllDevices();
}

/// Stream of the latest telemetry state for [deviceId].
///
/// Returns `null` when no MQTT message has been received yet for this device.
/// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
/// Phase 11 ([live_telemetry_provider]) will import it from here.
@riverpod
Stream<LatestState?> latestState(LatestStateRef ref, String deviceId) {
  final db = ref.watch(appDatabaseProvider);
  return db.telemetryDao.watchLatestState(deviceId);
}
