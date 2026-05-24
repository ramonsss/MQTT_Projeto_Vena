// J4 — Live telemetry providers
//
// latestStateProvider is already defined in devices_provider.dart (Phase 10).
// This file adds recentCacheProvider — the last 60 telemetry samples used
// by MiniChart.
//
// recentCacheProvider watches latestStateProvider as a trigger: every time
// a new MQTT message arrives and updates the latest_states row, Riverpod
// re-runs this future and the mini-chart re-draws with fresh data.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../devices/application/devices_provider.dart';

// Re-export so device_detail_screen only needs to import this file.
export '../../devices/application/devices_provider.dart'
    show latestStateProvider;

part 'live_telemetry_provider.g.dart';

/// Last [limit] telemetry samples for [deviceId], newest-first.
///
/// Automatically refreshes whenever [latestStateProvider] emits a new value,
/// which happens on each incoming MQTT telemetry message.
@riverpod
Future<List<TelemetryCacheData>> recentCache(
  RecentCacheRef ref,
  String deviceId, {
  int limit = 60,
}) async {
  // Depend on latestState so we re-fetch when new data arrives.
  ref.watch(latestStateProvider(deviceId));
  final db = ref.watch(appDatabaseProvider);
  return db.telemetryDao.getRecentCache(deviceId, limit: limit);
}
