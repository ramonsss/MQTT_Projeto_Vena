import 'package:drift/drift.dart';

/// Phase 5 — history cache.
///
/// Stores the most recent `HistoryResponse` payload for a `(deviceId, bucket,
/// rangeKey)` tuple so the app can re-open the history screen instantly while
/// the network round-trip is in flight (and so it still works offline).
///
/// TTL is enforced by the caller (5 min) via [fetchedAt]; [maxTs] enables
/// "newer telemetry → drop cache" invalidation.
class HistoryCache extends Table {
  TextColumn get deviceId => text()();
  TextColumn get bucket => text()(); // '5s' | '1m' | '1h' | '1d'
  TextColumn get rangeKey => text()(); // '1h' | '24h' | '7d' | '30d' | ...
  TextColumn get payload => text()(); // JSON-encoded HistoryResponse
  IntColumn get fetchedAt => integer()(); // unix seconds
  IntColumn get maxTs => integer()(); // newest ts inside payload, seconds

  @override
  Set<Column> get primaryKey => {deviceId, bucket, rangeKey};
}
