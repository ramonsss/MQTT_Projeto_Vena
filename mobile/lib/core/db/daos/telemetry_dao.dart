import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/latest_states_table.dart';
import '../tables/telemetry_cache_table.dart';

part 'telemetry_dao.g.dart';

@DriftAccessor(tables: [LatestStates, TelemetryCache])
class TelemetryDao extends DatabaseAccessor<AppDatabase>
    with _$TelemetryDaoMixin {
  TelemetryDao(super.db);

  // Stream of the latest state row for a single device.
  Stream<LatestState?> watchLatestState(String deviceId) =>
      (select(latestStates)
            ..where((t) => t.deviceId.equals(deviceId)))
          .watchSingleOrNull();

  // Insert or update the latest state row, but only when the new ts is
  // strictly newer than the stored one (most-recent wins).
  Future<void> upsertLatestState(LatestStatesCompanion entry) =>
      into(latestStates).insert(
        entry,
        onConflict: DoUpdate(
          (_) => entry,
          where: (old) => old.ts.isSmallerThanValue(entry.ts.value),
        ),
      );

  // Append one row to the telemetry ring buffer.
  Future<void> insertTelemetryCache(TelemetryCacheCompanion entry) =>
      into(telemetryCache).insertOnConflictUpdate(entry);

  // Return the most recent [limit] rows for a device, newest first.
  Future<List<TelemetryCacheData>> getRecentCache(
    String deviceId, {
    int limit = 60,
  }) =>
      (select(telemetryCache)
            ..where((t) => t.deviceId.equals(deviceId))
            ..orderBy([(t) => OrderingTerm.desc(t.ts)])
            ..limit(limit))
          .get();

  // Keep only the newest [keepCount] rows; delete the rest.
  Future<void> pruneOldEntries(String deviceId, {int keepCount = 1000}) async {
    // Find the timestamp of the (keepCount+1)-th newest row.
    final cutoff = await (select(telemetryCache)
          ..where((t) => t.deviceId.equals(deviceId))
          ..orderBy([(t) => OrderingTerm.desc(t.ts)])
          ..limit(1, offset: keepCount))
        .getSingleOrNull();

    if (cutoff != null) {
      await (delete(telemetryCache)
            ..where(
              (t) =>
                  t.deviceId.equals(deviceId) &
                  t.ts.isSmallerOrEqualValue(cutoff.ts),
            ))
          .go();
    }
  }
}
