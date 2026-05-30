// K2 — History provider
//
// historyProvider(deviceId, range) fetches GET /devices/{id}/history
// for the selected time range and caches the result for 5 minutes.
// After the TTL the next watch automatically re-fetches.
//
// HistoryRange encodes 24h / 7d / 30d as an enum so the router and UI
// can pass it as a type-safe value.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/device_api.dart';
import '../../../core/network/models/telemetry_point.dart';

part 'history_provider.g.dart';

// ── Range enum ───────────────────────────────────────────────────────────────

enum HistoryRange {
  h24(label: '24h', duration: Duration(hours: 24)),
  d7(label: '7d', duration: Duration(days: 7)),
  d30(label: '30d', duration: Duration(days: 30));

  const HistoryRange({required this.label, required this.duration});

  final String label;
  final Duration duration;
}

// ── Provider ─────────────────────────────────────────────────────────────────

/// Fetches telemetry history for [deviceId] over [range].
///
/// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
/// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
@riverpod
Future<List<TelemetryPoint>> history(
  HistoryRef ref,
  String deviceId,
  HistoryRange range,
) async {
  // 5-minute in-memory cache: keep provider alive and set a dispose timer.
  final link = ref.keepAlive();
  Future<void>.delayed(const Duration(minutes: 5), link.close);

  final now = DateTime.now();
  final start = now.subtract(range.duration);

  return ref.read(deviceApiProvider).getHistory(
        deviceId,
        start: start.millisecondsSinceEpoch ~/ 1000,
        end: now.millisecondsSinceEpoch ~/ 1000,
        limit: 500,
      );
}
