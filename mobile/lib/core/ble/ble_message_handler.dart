import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import 'ble_models.dart';
import 'ble_provider.dart';

part 'ble_message_handler.g.dart';

/// Persists incoming BLE telemetry into Drift/SQLite (same tables as MQTT).
class BleMessageHandler {
  const BleMessageHandler(this._db);

  final AppDatabase _db;

  Future<void> handle(BleTelemetry t) async {
    try {
      await _db.telemetryDao.upsertLatestState(
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

      await _db.telemetryDao.insertTelemetryCache(
        TelemetryCacheCompanion.insert(
          deviceId: t.deviceId,
          ts: t.ts,
          ambientT: Value(t.ambientT),
          ambientH: Value(t.ambientH),
          dissT: Value(t.dissT),
          dissH: Value(t.dissH),
        ),
      );

      await _db.telemetryDao.pruneOldEntries(t.deviceId);
    } catch (e) {
      debugPrint('[BLE handler] error: $e');
    }
  }
}

/// Singleton handler — wires itself to [bleServiceProvider].onTelemetry.
@Riverpod(keepAlive: true)
BleMessageHandler bleMessageHandler(BleMessageHandlerRef ref) {
  final db = ref.read(appDatabaseProvider);
  final handler = BleMessageHandler(db);

  final sub = ref
      .read(bleServiceProvider)
      .onTelemetry
      .listen((t) => unawaited(handler.handle(t)));

  ref.onDispose(sub.cancel);
  return handler;
}
