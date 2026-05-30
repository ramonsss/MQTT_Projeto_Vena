// T5 — DeviceDao.watchAllDevices: stream re-emits after insert/update.
// T6 — TelemetryDao.pruneOldEntries: keeps only the N newest rows per device.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // ── T5: DeviceDao.watchAllDevices ──────────────────────────────────────
  group('T5 – DeviceDao.watchAllDevices', () {
    test('emits empty list initially', () async {
      final devices = await db.deviceDao.watchAllDevices().first;
      expect(devices, isEmpty);
    });

    test('emits updated list after a single upsert', () async {
      await db.deviceDao
          .upsertDevice(DevicesCompanion.insert(deviceId: 'dev1'));

      final devices = await db.deviceDao.watchAllDevices().first;
      expect(devices.length, 1);
      expect(devices.first.deviceId, 'dev1');
    });

    test('stream re-emits when a second device is upserted', () async {
      final emitted = <int>[];
      final sub =
          db.deviceDao.watchAllDevices().listen((list) => emitted.add(list.length));

      await db.deviceDao
          .upsertDevice(DevicesCompanion.insert(deviceId: 'dev1'));
      await db.deviceDao
          .upsertDevice(DevicesCompanion.insert(deviceId: 'dev2'));
      await Future.delayed(Duration.zero);

      await sub.cancel();
      expect(emitted, contains(2));
    });

    test('updateAlias modifies alias without removing device', () async {
      await db.deviceDao
          .upsertDevice(DevicesCompanion.insert(deviceId: 'dev1'));
      await db.deviceDao.updateAlias('dev1', 'Câmara Fria');

      final devices = await db.deviceDao.watchAllDevices().first;
      expect(devices.first.alias, 'Câmara Fria');
    });
  });

  // ── T6: TelemetryDao.pruneOldEntries ──────────────────────────────────
  group('T6 – TelemetryDao.pruneOldEntries', () {
    Future<void> insertRows(String deviceId, List<int> timestamps) async {
      for (final ts in timestamps) {
        await db.telemetryDao.insertTelemetryCache(
          TelemetryCacheCompanion.insert(deviceId: deviceId, ts: ts),
        );
      }
    }

    test('keeps only the newest N rows when over limit', () async {
      await insertRows('dev1', [1, 2, 3, 4, 5]);
      await db.telemetryDao.pruneOldEntries('dev1', keepCount: 3);

      final rows =
          await db.telemetryDao.getRecentCache('dev1', limit: 100);
      expect(rows.length, 3);
      // getRecentCache returns newest-first, so ts 5, 4, 3
      expect(rows.map((r) => r.ts).toSet(), equals({3, 4, 5}));
    });

    test('does not delete rows when count is within limit', () async {
      await insertRows('dev1', [1, 2]);
      await db.telemetryDao.pruneOldEntries('dev1', keepCount: 5);

      final rows =
          await db.telemetryDao.getRecentCache('dev1', limit: 100);
      expect(rows.length, 2);
    });

    test('no-op when table is empty', () async {
      await expectLater(
        db.telemetryDao.pruneOldEntries('dev1', keepCount: 3),
        completes,
      );
    });

    test('only prunes the specified device, leaves others intact', () async {
      await insertRows('dev1', [1, 2, 3, 4, 5]);
      await insertRows('dev2', [10, 20]);

      await db.telemetryDao.pruneOldEntries('dev1', keepCount: 2);

      final dev1 =
          await db.telemetryDao.getRecentCache('dev1', limit: 100);
      final dev2 =
          await db.telemetryDao.getRecentCache('dev2', limit: 100);

      expect(dev1.length, 2);
      expect(dev2.length, 2); // unchanged
    });
  });
}
