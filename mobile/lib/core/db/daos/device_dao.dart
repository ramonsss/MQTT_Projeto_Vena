import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/devices_table.dart';

part 'device_dao.g.dart';

@DriftAccessor(tables: [Devices])
class DeviceDao extends DatabaseAccessor<AppDatabase> with _$DeviceDaoMixin {
  DeviceDao(super.db);

  // Stream that re-emits whenever the devices table changes.
  Stream<List<Device>> watchAllDevices() => select(devices).watch();

  // Insert or replace a device row.
  Future<void> upsertDevice(DevicesCompanion entry) =>
      into(devices).insertOnConflictUpdate(entry);

  // Update only the alias field for a given deviceId.
  Future<void> updateAlias(String deviceId, String alias) =>
      (update(devices)..where((t) => t.deviceId.equals(deviceId))).write(
        DevicesCompanion(alias: Value(alias)),
      );
}
