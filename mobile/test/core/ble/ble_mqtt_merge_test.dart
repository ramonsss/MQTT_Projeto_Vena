// T11 — BLE + MQTT merge integration test:
//   Uses the real in-memory Drift DB with both BleMessageHandler and
//   MqttMessageHandler writing to the same latest_states table.
//
//   Scenario A: BLE ts=100, MQTT ts=102 → latest shows ts=102, source='mqtt'
//   Scenario B: After A, BLE ts=104     → latest shows ts=104, source='ble'
//   Scenario C: Stale write (ts < current) does not overwrite the row.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/core/ble/ble_message_handler.dart';
import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/core/mqtt/models/mqtt_topic_message.dart';
import 'package:vena_app/core/mqtt/mqtt_message_handler.dart';

void main() {
  late AppDatabase db;
  late BleMessageHandler bleHandler;
  late MqttMessageHandler mqttHandler;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    bleHandler = BleMessageHandler(db);
    mqttHandler = MqttMessageHandler(db);
  });

  tearDown(() => db.close());

  // Helper: write a BLE telemetry row.
  Future<void> writeBle({
    required int ts,
    String deviceId = 'vena-abc1',
    double ambientT = 22.0,
  }) =>
      bleHandler.handle(
        BleTelemetry(
          deviceId: deviceId,
          ts: ts,
          ambientT: ambientT,
          ambientH: null,
          dissT: null,
          dissH: null,
          setpoint: null,
          pidOut: null,
        ),
      );

  // Helper: write an MQTT telemetry row.
  Future<void> writeMqtt({
    required int ts,
    String deviceId = 'vena-abc1',
    double ambientT = 22.0,
  }) =>
      mqttHandler.handle(
        MqttTopicMessage(
          topic: 'vena/$deviceId/telemetry',
          payload: jsonEncode({
            'ts': ts,
            'ambient_t': ambientT,
          }),
        ),
      );

  group('T11 – BLE + MQTT merge', () {
    test('MQTT ts=102 after BLE ts=100 → latest is mqtt source', () async {
      await writeBle(ts: 100, ambientT: 20.0);
      await writeMqtt(ts: 102, ambientT: 21.0);

      final row =
          await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row, isNotNull);
      expect(row!.ts, 102);
      expect(row.source, 'mqtt');
      expect(row.ambientT, 21.0);
    });

    test('BLE ts=104 after MQTT ts=102 → latest switches to ble source',
        () async {
      await writeBle(ts: 100, ambientT: 20.0);
      await writeMqtt(ts: 102, ambientT: 21.0);
      await writeBle(ts: 104, ambientT: 23.0);

      final row =
          await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row!.ts, 104);
      expect(row.source, 'ble');
      expect(row.ambientT, 23.0);
    });

    test('stale MQTT write (ts < current) does not overwrite newer BLE row',
        () async {
      await writeBle(ts: 200, ambientT: 25.0);

      // Stale MQTT message with older ts
      await writeMqtt(ts: 50, ambientT: 10.0);

      final row =
          await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row!.ts, 200);
      expect(row.source, 'ble');
      expect(row.ambientT, 25.0);
    });

    test('stale BLE write does not overwrite newer MQTT row', () async {
      await writeMqtt(ts: 300, ambientT: 30.0);

      // Stale BLE message with older ts
      await writeBle(ts: 100, ambientT: 10.0);

      final row =
          await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row!.ts, 300);
      expect(row.source, 'mqtt');
      expect(row.ambientT, 30.0);
    });

    test('two devices are stored and retrieved independently', () async {
      await writeBle(ts: 100, deviceId: 'vena-a', ambientT: 10.0);
      await writeMqtt(ts: 200, deviceId: 'vena-b', ambientT: 20.0);

      final rowA =
          await db.telemetryDao.watchLatestState('vena-a').first;
      final rowB =
          await db.telemetryDao.watchLatestState('vena-b').first;

      expect(rowA!.source, 'ble');
      expect(rowA.ambientT, 10.0);
      expect(rowB!.source, 'mqtt');
      expect(rowB.ambientT, 20.0);
    });
  });
}
