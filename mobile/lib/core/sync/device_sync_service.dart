import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../network/device_api.dart';

/// Fetches the user's device list from the backend and upserts it into Drift.
///
/// Called:
/// - After login (in SplashScreen / post-auth flow).
/// - On pull-to-refresh in DevicesScreen.
class DeviceSyncService {
  const DeviceSyncService({
    required DeviceApi deviceApi,
    required AppDatabase db,
  })  : _deviceApi = deviceApi,
        _db = db;

  final DeviceApi _deviceApi;
  final AppDatabase _db;

  /// Pulls `GET /devices` and upserts every device into the local Drift table.
  Future<void> syncDeviceList() async {
    final devices = await _deviceApi.listDevices();
    for (final dto in devices) {
      await _db.deviceDao.upsertDevice(dto.toCompanion());
    }
  }
}

final deviceSyncServiceProvider = Provider<DeviceSyncService>((ref) {
  return DeviceSyncService(
    deviceApi: ref.read(deviceApiProvider),
    db: ref.read(appDatabaseProvider),
  );
});
