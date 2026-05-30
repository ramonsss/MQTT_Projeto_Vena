import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/history_cache_table.dart';

part 'history_cache_dao.g.dart';

@DriftAccessor(tables: [HistoryCache])
class HistoryCacheDao extends DatabaseAccessor<AppDatabase>
    with _$HistoryCacheDaoMixin {
  HistoryCacheDao(super.db);

  /// Returns the cached row for `(deviceId, bucket, rangeKey)`, or null.
  Future<HistoryCacheData?> get(
    String deviceId,
    String bucket,
    String rangeKey,
  ) =>
      (select(historyCache)
            ..where(
              (t) =>
                  t.deviceId.equals(deviceId) &
                  t.bucket.equals(bucket) &
                  t.rangeKey.equals(rangeKey),
            ))
          .getSingleOrNull();

  /// Upsert (PK = device + bucket + rangeKey).
  Future<void> upsert(HistoryCacheCompanion entry) =>
      into(historyCache).insertOnConflictUpdate(entry);

  /// Delete every cached entry for [deviceId] whose [HistoryCache.maxTs] is
  /// older than [newTs] — i.e. brand-new telemetry just arrived. The next
  /// `get` call returns null and the provider refetches.
  Future<int> invalidateStale(String deviceId, int newTs) async {
    return (delete(historyCache)
          ..where(
            (t) => t.deviceId.equals(deviceId) & t.maxTs.isSmallerThanValue(newTs),
          ))
        .go();
  }

  /// Wipe every cached entry for a device (used on logout / device removal).
  Future<int> deleteForDevice(String deviceId) =>
      (delete(historyCache)..where((t) => t.deviceId.equals(deviceId))).go();
}
