// I4 — Device mutation actions
//
// claimDevice  : inserts a `claim` outbox entry + best-effort device sync.
// renameDevice : optimistic local alias update + queues `rename` outbox entry.
//
// Both writes go through Drift first so the UI reflects changes instantly
// even if the network is unavailable. [OutboxWorker] handles backend sync.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/device_sync_service.dart';

part 'device_actions_provider.g.dart';

/// Exposes write operations for the devices feature.
///
/// State is `void` — callers `await` the async methods and react to errors.
@riverpod
class DeviceActions extends _$DeviceActions {
  @override
  void build() {}

  // ── Public API ─────────────────────────────────────────────────────────

  /// Queues a `claim` outbox entry and triggers an immediate device-list
  /// sync so the newly claimed device appears in the UI without delay.
  Future<void> claimDevice(String deviceId, String pairingCode) async {
    final db = ref.read(appDatabaseProvider);
    await db.outboxDao.insertAction(
      OutboxCompanion(
        action: const Value('claim'),
        payload: Value(
          jsonEncode({'device_id': deviceId, 'pairing_code': pairingCode}),
        ),
        createdAt: Value(DateTime.now()),
      ),
    );
    // Best-effort sync — failure is non-fatal; OutboxWorker will retry.
    await ref.read(deviceSyncServiceProvider).syncDeviceList();
  }

  /// Applies an optimistic local alias update then queues a `rename` entry
  /// so the change is eventually propagated to the backend via [OutboxWorker].
  Future<void> renameDevice(String deviceId, String alias) async {
    final db = ref.read(appDatabaseProvider);
    // Optimistic update: UI reflects the new alias immediately.
    await db.deviceDao.updateAlias(deviceId, alias);
    // Queue backend sync.
    await db.outboxDao.insertAction(
      OutboxCompanion(
        action: const Value('rename'),
        payload: Value(jsonEncode({'device_id': deviceId, 'alias': alias})),
        createdAt: Value(DateTime.now()),
      ),
    );
  }
}
