import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../network/device_api.dart';

part 'outbox_worker.g.dart';

/// Processes pending [Outbox] entries and syncs them to the backend.
///
/// Flow per entry:
/// - `claim`  → `POST /devices/{id}/claim`
/// - `rename` → `PATCH /devices/{id}`
///
/// On success  → mark `synced = true`.
/// On HTTP 409 → server wins; mark synced and discard local change.
/// On network  → stop batch, schedule retry in 30 s.
class OutboxWorker {
  OutboxWorker({required AppDatabase db, required DeviceApi deviceApi})
      : _db = db,
        _deviceApi = deviceApi;

  final AppDatabase _db;
  final DeviceApi _deviceApi;

  StreamSubscription<List<OutboxData>>? _sub;
  Timer? _retryTimer;
  bool _processing = false;

  /// Starts listening to the pending-outbox stream.
  void start() {
    _sub = _db.outboxDao.watchPending().listen((pending) {
      if (pending.isNotEmpty && !_processing) {
        unawaited(_processBatch(pending));
      }
    });
  }

  /// Stops listening and cancels any pending retry timer.
  void stop() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _processing = false;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _processBatch(List<OutboxData> items) async {
    _processing = true;
    var hadNetworkError = false;

    for (final item in items) {
      try {
        await _execute(item);
        await _db.outboxDao.markSynced(item.id);
        debugPrint('[Outbox] synced item ${item.id} (${item.action})');
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          // Conflict — server wins; treat as resolved.
          debugPrint('[Outbox] 409 on item ${item.id} — server wins');
          await _db.outboxDao.markSynced(item.id);
        } else {
          debugPrint('[Outbox] network error on item ${item.id}: $e');
          hadNetworkError = true;
          break; // leave remaining items for the retry pass
        }
      } catch (e) {
        debugPrint('[Outbox] unexpected error on item ${item.id}: $e');
        hadNetworkError = true;
        break;
      }
    }

    _processing = false;

    if (hadNetworkError) {
      _scheduleRetry();
    }
  }

  Future<void> _execute(OutboxData item) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;

    switch (item.action) {
      case 'claim':
        await _deviceApi.claimDevice(
          payload['device_id'] as String,
          payload['pairing_code'] as String,
        );
      case 'rename':
        await _deviceApi.updateAlias(
          payload['device_id'] as String,
          payload['alias'] as String,
        );
      default:
        debugPrint('[Outbox] unknown action: ${item.action}');
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () async {
      final pending = await _db.outboxDao.watchPending().first;
      if (pending.isNotEmpty) {
        unawaited(_processBatch(pending));
      }
    });
  }
}

/// Singleton worker — starts immediately and stays alive for the session.
@Riverpod(keepAlive: true)
OutboxWorker outboxWorker(OutboxWorkerRef ref) {
  final worker = OutboxWorker(
    db: ref.read(appDatabaseProvider),
    deviceApi: ref.read(deviceApiProvider),
  );
  worker.start();
  ref.onDispose(worker.stop);
  return worker;
}
