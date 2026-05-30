// T3 — MqttService: basic contract (broadcast stream, subscribe, dispose).
// T4 — MqttMessageHandler: JSON telemetry + status → Drift DB writes.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNotNull;
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/auth/secure_token_storage.dart';
import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/core/mqtt/models/mqtt_topic_message.dart';
import 'package:vena_app/core/mqtt/mqtt_message_handler.dart';
import 'package:vena_app/core/mqtt/mqtt_service.dart';
import 'package:vena_app/core/network/mqtt_api.dart';

class _MockMqttApi extends Mock implements MqttApi {}

class _MockStorage extends Mock implements SecureTokenStorage {}

void main() {
  // ── T3: MqttService ────────────────────────────────────────────────────
  group('T3 – MqttService', () {
    late MqttService sut;

    setUp(() {
      sut = MqttService(
        mqttApi: _MockMqttApi(),
        storage: _MockStorage(),
      );
    });

    tearDown(() => sut.dispose());

    test('onMessage is a broadcast stream', () {
      expect(sut.onMessage.isBroadcast, isTrue);
    });

    test('connectionState is a broadcast stream', () {
      expect(sut.connectionState.isBroadcast, isTrue);
    });

    test('subscribe with empty list does not throw', () {
      expect(() => sut.subscribe([]), returnsNormally);
    });

    test('subscribe with device IDs does not throw', () {
      expect(() => sut.subscribe(['dev1', 'dev2']), returnsNormally);
    });

    test('dispose closes streams without error', () {
      expect(() => sut.dispose(), returnsNormally);
    });

    test('calling disconnect before connect does not throw', () async {
      await expectLater(sut.disconnect(), completes);
    });
  });

  // ── T4: MqttMessageHandler ─────────────────────────────────────────────
  group('T4 – MqttMessageHandler', () {
    late AppDatabase db;
    late MqttMessageHandler handler;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      handler = MqttMessageHandler(db);
    });

    tearDown(() => db.close());

    // ── Telemetry messages ────────────────────────────────────────────────

    test('telemetry upserts latest_state with parsed values', () async {
      await handler.handle(const MqttTopicMessage(
        topic: 'vena/dev1/telemetry',
        payload:
            '{"ts":1000,"ambient_t":22.5,"ambient_h":65.0,"setpoint":22.0,"pid_out":12.3}',
      ));

      final state = await db.telemetryDao.watchLatestState('dev1').first;
      expect(state, isA<LatestState>());
      expect(state!.ambientT, 22.5);
      expect(state.ambientH, 65.0);
      expect(state.setpoint, 22.0);
      expect(state.pidOut, 12.3);
      expect(state.online, isTrue);
      expect(state.source, 'mqtt');
    });

    test('telemetry inserts a row into telemetry_cache', () async {
      await handler.handle(const MqttTopicMessage(
        topic: 'vena/dev1/telemetry',
        payload: '{"ts":2000,"ambient_t":18.0,"ambient_h":70.0}',
      ));

      final cache = await db.telemetryDao.getRecentCache('dev1');
      expect(cache.length, 1);
      expect(cache.first.ambientT, 18.0);
      expect(cache.first.ts, 2000);
    });

    test('telemetry second message overwrites latest_state ts', () async {
      await handler.handle(const MqttTopicMessage(
        topic: 'vena/dev1/telemetry',
        payload: '{"ts":1000,"ambient_t":20.0}',
      ));
      await handler.handle(const MqttTopicMessage(
        topic: 'vena/dev1/telemetry',
        payload: '{"ts":2000,"ambient_t":21.0}',
      ));

      final state = await db.telemetryDao.watchLatestState('dev1').first;
      expect(state!.ts, 2000);
      expect(state.ambientT, 21.0);

      // cache should have both rows
      final cache = await db.telemetryDao.getRecentCache('dev1', limit: 10);
      expect(cache.length, 2);
    });

    // ── Status messages ───────────────────────────────────────────────────

    test('status:offline updates device status field', () async {
      await db.deviceDao
          .upsertDevice(DevicesCompanion.insert(deviceId: 'dev1'));

      await handler.handle(const MqttTopicMessage(
        topic: 'vena/dev1/status',
        payload: '{"online":false,"fw_version":"1.2.0"}',
      ));

      final devices = await db.deviceDao.watchAllDevices().first;
      expect(devices.first.status, 'offline');
      expect(devices.first.fwVersion, '1.2.0');
    });

    test('status:online updates device status field', () async {
      await db.deviceDao
          .upsertDevice(DevicesCompanion.insert(deviceId: 'dev1'));

      await handler.handle(const MqttTopicMessage(
        topic: 'vena/dev1/status',
        payload: '{"online":true}',
      ));

      final devices = await db.deviceDao.watchAllDevices().first;
      expect(devices.first.status, 'online');
    });

    // ── Edge cases ────────────────────────────────────────────────────────

    test('malformed topic (too short) does not throw', () async {
      await expectLater(
        handler.handle(
            const MqttTopicMessage(topic: 'vena/only', payload: '{}')),
        completes,
      );
    });

    test('unknown topic type is silently ignored', () async {
      await expectLater(
        handler.handle(const MqttTopicMessage(
            topic: 'vena/dev1/unknown', payload: '{}')),
        completes,
      );
    });

    test('invalid JSON payload does not propagate exception', () async {
      await expectLater(
        handler.handle(const MqttTopicMessage(
            topic: 'vena/dev1/telemetry', payload: 'not-json')),
        completes,
      );
    });
  });
}
