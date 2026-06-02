import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
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

/// Persists BLE telemetry to Drift (mirrors MqttMessageHandler for BLE source).
/// Manual Provider — no code generation needed, kept alive by default.
final bleMessageHandlerProvider = Provider<Object>((ref) {
  final db = ref.read(appDatabaseProvider);

  final sub = ref.read(bleServiceProvider).onTelemetry.listen(
    (t) async {
      try {
        await db.telemetryDao.upsertLatestState(
          LatestStatesCompanion.insert(
            deviceId: t.deviceId,
            ts: t.ts,
            ambientT: Value(t.ambientT),
            ambientH: Value(t.ambientH),
            dissT: Value(t.dissT),
            dissH: Value(t.dissH),
            setpoint: Value(t.setpoint),
            pidOut: Value(t.pidOut),
            source: const Value('ble'),
            online: const Value(true),
          ),
        );
        await db.telemetryDao.insertTelemetryCache(
          TelemetryCacheCompanion.insert(
            deviceId: t.deviceId,
            ts: t.ts,
            ambientT: Value(t.ambientT),
            ambientH: Value(t.ambientH),
            dissT: Value(t.dissT),
            dissH: Value(t.dissH),
          ),
        );
        await db.telemetryDao.pruneOldEntries(t.deviceId);
      } catch (e) {
        debugPrint('[BLE handler] drift write error: $e');
      }
    },
    onError: (e) => debugPrint('[BLE handler] stream error: $e'),
  );

  ref.onDispose(sub.cancel);
  return sub;
});
