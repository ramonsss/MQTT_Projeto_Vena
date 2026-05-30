import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles BLE-related runtime permissions (Android 12+).
class BlePermissionHandler {
  /// Requests all necessary BLE permissions.
  /// Returns `true` if all required permissions are granted.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    // Android ≤11 needs location for BLE scanning
    if (Platform.isAndroid) {
      final sdkInt = int.tryParse(
            Platform.environment['ro.build.version.sdk'] ?? '',
          ) ??
          33;
      if (sdkInt < 31) {
        permissions.add(Permission.locationWhenInUse);
      }
    }

    if (Platform.isIOS) {
      permissions.add(Permission.bluetooth);
    }

    final statuses = await permissions.request();

    final allGranted = statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );

    if (!allGranted) {
      debugPrint('[BLE] permissions not fully granted: $statuses');
    }

    return allGranted;
  }

  /// Checks if BLE permissions are already granted.
  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final scan = await Permission.bluetoothScan.isGranted;
    final connect = await Permission.bluetoothConnect.isGranted;
    return scan && connect;
  }
}
