import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables/devices_table.dart';
import 'tables/history_cache_table.dart';
import 'tables/latest_states_table.dart';
import 'tables/telemetry_cache_table.dart';
import 'tables/outbox_table.dart';
import 'tables/user_session_table.dart';
import 'daos/device_dao.dart';
import 'daos/history_cache_dao.dart';
import 'daos/telemetry_dao.dart';
import 'daos/outbox_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Devices,
    LatestStates,
    TelemetryCache,
    HistoryCache,
    Outbox,
    UserSession,
  ],
  daos: [DeviceDao, TelemetryDao, OutboxDao, HistoryCacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'vena_app'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(devices, devices.storedContent);
      }
      if (from < 3) {
        await m.createTable(historyCache);
      }
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden in main()');
});
