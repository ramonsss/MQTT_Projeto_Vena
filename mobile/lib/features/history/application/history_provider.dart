// K2 — History provider (Phase 5).
//
// historyProvider(deviceId, range) fetches `GET /devices/{id}/history`
// using the new adaptive-bucket endpoint. Results are cached locally in
// Drift (`history_cache` table) with a 5-minute TTL so the next open
// is instant and works offline.
//
// Invalidation: callers (live screen / MQTT handler) should call
// `ref.read(historyInvalidatorProvider)(deviceId, newTsSec)` whenever
// a fresh telemetry sample arrives — this drops cached rows whose
// `maxTs` is older than `newTsSec`.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/history_cache_dao.dart';
import '../../../core/network/device_api.dart';
import '../../../core/network/models/telemetry_point.dart';

part 'history_provider.g.dart';

// ── Range enum ───────────────────────────────────────────────────────────────

enum HistoryRange {
  h1(label: '1h', apiValue: '1h', duration: Duration(hours: 1)),
  h24(label: '24h', apiValue: '24h', duration: Duration(hours: 24)),
  d7(label: '7d', apiValue: '7d', duration: Duration(days: 7)),
  d30(label: '30d', apiValue: '30d', duration: Duration(days: 30));

  const HistoryRange({
    required this.label,
    required this.apiValue,
    required this.duration,
  });

  final String label;
  final String apiValue;
  final Duration duration;
}

// ── Cache TTL ────────────────────────────────────────────────────────────────

const Duration kHistoryCacheTtl = Duration(minutes: 5);

// ── Provider ─────────────────────────────────────────────────────────────────

/// Provider for the [HistoryCacheDao] — overridable in tests.
final historyCacheDaoProvider = Provider<HistoryCacheDao?>((ref) {
  // Mobile main() wires AppDatabase; unit tests may leave this null, in
  // which case the provider skips the cache layer entirely.
  try {
    return ref.read(appDatabaseProvider).historyCacheDao;
  } catch (_) {
    return null;
  }
});

/// Fetches telemetry history for [deviceId] over [range].
///
/// Strategy:
/// 1. Read `history_cache` row for `(deviceId, bucket='auto'-resolved, range)`.
/// 2. If fresh (`fetchedAt` within [kHistoryCacheTtl]) → return cached samples.
/// 3. Otherwise fetch from the API, persist the new envelope, return samples.
///
/// Riverpod also keeps the in-memory result alive for 5 min via [keepAlive]
/// so widgets remounting in the same session avoid even the Drift round-trip.
@riverpod
Future<List<TelemetryPoint>> history(
  HistoryRef ref,
  String deviceId,
  HistoryRange range,
) async {
  // 5-minute in-memory cache: keep provider alive and set a dispose timer.
  final link = ref.keepAlive();
  Future<void>.delayed(kHistoryCacheTtl, link.close);

  final api = ref.read(deviceApiProvider);
  final dao = ref.read(historyCacheDaoProvider);

  // Bucket key in the Drift cache reflects what the backend picked. We use
  // 'auto' as the lookup discriminator since the resolved bucket is purely a
  // function of `range` (see backend `choose_bucket`).
  const cacheBucket = 'auto';
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final ttlSec = kHistoryCacheTtl.inSeconds;

  // ── 1. Try cache ────────────────────────────────────────────────────────
  if (dao != null) {
    final cached = await dao.get(deviceId, cacheBucket, range.apiValue);
    if (cached != null && (nowSec - cached.fetchedAt) <= ttlSec) {
      try {
        final decoded = jsonDecode(cached.payload) as Map<String, dynamic>;
        final envelope = HistoryResponse.fromJson(decoded);
        return envelope.samples;
      } catch (_) {
        // Corrupt cache row — fall through to network.
      }
    }
  }

  // ── 2. Fetch fresh ──────────────────────────────────────────────────────
  final envelope = await api.fetchHistoryResponse(
    deviceId,
    range: range.apiValue,
  );

  // ── 3. Persist ──────────────────────────────────────────────────────────
  if (dao != null) {
    final maxTs = envelope.samples.isEmpty
        ? 0
        : envelope.samples
            .map((s) => s.ts)
            .reduce((a, b) => a > b ? a : b);
    final payload = jsonEncode({
      'device_id': envelope.deviceId,
      'count': envelope.count,
      'samples': envelope.samples.map((s) => s.toJson()).toList(),
      if (envelope.bucket != null) 'bucket': envelope.bucket,
      if (envelope.rangeStart != null)
        'range_start': envelope.rangeStart!.toUtc().toIso8601String(),
      if (envelope.rangeEnd != null)
        'range_end': envelope.rangeEnd!.toUtc().toIso8601String(),
    });
    await dao.upsert(
      HistoryCacheCompanion(
        deviceId: Value(deviceId),
        bucket: const Value(cacheBucket),
        rangeKey: Value(range.apiValue),
        payload: Value(payload),
        fetchedAt: Value(nowSec),
        maxTs: Value(maxTs),
      ),
    );
  }

  return envelope.samples;
}

// ── Invalidation helper ──────────────────────────────────────────────────────

/// Function signature: `(deviceId, newTsSec) → Future<void>`.
typedef HistoryInvalidator = Future<void> Function(String deviceId, int newTs);

/// Drops any cached history rows whose newest sample is older than [newTs]
/// and invalidates the in-memory Riverpod entries for [deviceId].
///
/// Call this from the live telemetry pipeline whenever a brand-new sample
/// arrives via MQTT / WebSocket. Costs one cheap SQL DELETE; safe to call
/// on every incoming message.
final historyInvalidatorProvider = Provider<HistoryInvalidator>((ref) {
  return (String deviceId, int newTs) async {
    final dao = ref.read(historyCacheDaoProvider);
    if (dao != null) {
      await dao.invalidateStale(deviceId, newTs);
    }
    for (final r in HistoryRange.values) {
      ref.invalidate(historyProvider(deviceId, r));
    }
  };
});

