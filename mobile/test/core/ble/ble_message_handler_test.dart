// T3 — BleMessageHandler:
//   • BleTelemetry → upsert latest_states with source='ble'.
//   • Most-recent ts wins over an older entry.
//   • telemetry_cache row is inserted for every call.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/core/ble/ble_message_handler.dart';
import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/db/app_database.dart';

BleTelemetry _telemetry({
  String deviceId = 'vena-abc1',
  int ts = 1000,
  double ambientT = 22.5,
  double ambientH = 65.0,
}) =>
    BleTelemetry(
      deviceId: deviceId,
      ts: ts,
      ambientT: ambientT,
      ambientH: ambientH,
      dissT: null,
      dissH: null,
      setpoint: null,
      pidOut: null,
    );

void main() {
  late AppDatabase db;
  late BleMessageHandler handler;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    handler = BleMessageHandler(db);
  });

  tearDown(() => db.close());

  group('T3 – BleMessageHandler', () {
    test('inserts latest_state with source=ble', () async {
      await handler.handle(_telemetry());

      final row = await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row, isNotNull);
      expect(row!.source, 'ble');
      expect(row.ambientT, 22.5);
    });

    test('inserts a telemetry_cache row for every call', () async {
      await handler.handle(_telemetry(ts: 1));
      await handler.handle(_telemetry(ts: 2));

      final rows = await db.telemetryDao.getRecentCache('vena-abc1', limit: 10);
      expect(rows.length, 2);
    });

    test('newer ts overwrites older latest_state', () async {
      await handler.handle(_telemetry(ts: 100, ambientT: 20.0));
      await handler.handle(_telemetry(ts: 200, ambientT: 25.0));

      final row = await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row!.ts, 200);
      expect(row.ambientT, 25.0);
      expect(row.source, 'ble');
    });

    test('older ts does NOT overwrite a newer latest_state', () async {
      await handler.handle(_telemetry(ts: 200, ambientT: 25.0));
      await handler.handle(_telemetry(ts: 100, ambientT: 20.0));

      final row = await db.telemetryDao.watchLatestState('vena-abc1').first;
      expect(row!.ts, 200);
      expect(row.ambientT, 25.0);
    });

    test('handles multiple devices independently', () async {
      await handler.handle(_telemetry(deviceId: 'vena-a', ts: 1, ambientT: 10.0));
      await handler.handle(_telemetry(deviceId: 'vena-b', ts: 2, ambientT: 20.0));

      final rowA = await db.telemetryDao.watchLatestState('vena-a').first;
      final rowB = await db.telemetryDao.watchLatestState('vena-b').first;
      expect(rowA!.ambientT, 10.0);
      expect(rowB!.ambientT, 20.0);
    });
  });
}
