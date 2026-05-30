import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import 'models/mqtt_topic_message.dart';
import 'mqtt_provider.dart';

part 'mqtt_message_handler.g.dart';

/// Parses incoming MQTT messages and persists them to Drift/SQLite.
///
/// Topic routing:
/// - `vena/{deviceId}/telemetry` → upsert [LatestStates] + insert [TelemetryCache] + prune.
/// - `vena/{deviceId}/status`    → partial update [LatestStates].online + [Devices].status.
class MqttMessageHandler {
  const MqttMessageHandler(this._db);

  final AppDatabase _db;

  Future<void> handle(MqttTopicMessage msg) async {
    try {
      final parts = msg.topic.split('/');
      if (parts.length < 3) return; // unexpected topic shape

      final deviceId = parts[1];
      final type = parts[2];
      final json = jsonDecode(msg.payload) as Map<String, dynamic>;

      switch (type) {
        case 'telemetry':
          await _handleTelemetry(deviceId, json);
        case 'status':
          await _handleStatus(deviceId, json);
      }
    } catch (e) {
      debugPrint('[MQTT handler] error on ${msg.topic}: $e');
    }
  }

  // ── Telemetry ─────────────────────────────────────────────────────────────

  Future<void> _handleTelemetry(
    String deviceId,
    Map<String, dynamic> json,
  ) async {
    final ts = json['ts'] as int;
    final ambientT = (json['ambient_t'] as num?)?.toDouble();
    final ambientH = (json['ambient_h'] as num?)?.toDouble();
    final dissT = (json['diss_t'] as num?)?.toDouble();
    final dissH = (json['diss_h'] as num?)?.toDouble();
    final setpoint = (json['setpoint'] as num?)?.toDouble();
    final pidOut = (json['pid_out'] as num?)?.toDouble();

    // Overwrite the single "latest" row for this device.
    await _db.telemetryDao.upsertLatestState(
      LatestStatesCompanion.insert(
        deviceId: deviceId,
        ts: ts,
        ambientT: Value(ambientT),
        ambientH: Value(ambientH),
        dissT: Value(dissT),
        dissH: Value(dissH),
        setpoint: Value(setpoint),
        pidOut: Value(pidOut),
        source: const Value('mqtt'),
        online: const Value(true),
      ),
    );

    // Append to ring-buffer cache (for mini-chart).
    await _db.telemetryDao.insertTelemetryCache(
      TelemetryCacheCompanion.insert(
        deviceId: deviceId,
        ts: ts,
        ambientT: Value(ambientT),
        ambientH: Value(ambientH),
        dissT: Value(dissT),
        dissH: Value(dissH),
      ),
    );

    // Keep ring buffer bounded.
    await _db.telemetryDao.pruneOldEntries(deviceId);
  }

  // ── Status ────────────────────────────────────────────────────────────────

  Future<void> _handleStatus(
    String deviceId,
    Map<String, dynamic> json,
  ) async {
    final online = json['online'] as bool;
    final fwVersion = json['fw_version'] as String?;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Partial update — only touch the online flag.
    await (_db.update(_db.latestStates)
          ..where((t) => t.deviceId.equals(deviceId)))
        .write(LatestStatesCompanion(online: Value(online)));

    // Partial update — device status + last-seen timestamp.
    await (_db.update(_db.devices)
          ..where((t) => t.deviceId.equals(deviceId)))
        .write(
      DevicesCompanion(
        status: Value(online ? 'online' : 'offline'),
        lastSeenAt: Value(now),
        fwVersion:
            fwVersion != null ? Value(fwVersion) : const Value.absent(),
      ),
    );
  }
}

/// Singleton handler — wires itself to [mqttServiceProvider].onMessage.
/// Keep alive so the subscription persists for the whole session.
@Riverpod(keepAlive: true)
MqttMessageHandler mqttMessageHandler(MqttMessageHandlerRef ref) {
  final db = ref.read(appDatabaseProvider);
  final handler = MqttMessageHandler(db);

  final sub = ref
      .read(mqttServiceProvider)
      .onMessage
      .listen((msg) => unawaited(handler.handle(msg)));

  ref.onDispose(sub.cancel);
  return handler;
}
