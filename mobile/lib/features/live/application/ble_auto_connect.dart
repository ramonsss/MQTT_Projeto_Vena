import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ble/ble_models.dart';
import '../../../core/ble/ble_provider.dart';

/// Derives the BLE advertised name from a logical device_id.
///
/// device_id format: `vena-aabbccddeeff`
/// BLE name format:  `Vena-EEFF`  (last 4 hex chars, upper-cased)
String bleNameFromDeviceId(String deviceId) {
  final hex = deviceId.replaceFirst('vena-', '');
  if (hex.length < 4) return '';
  return 'Vena-${hex.substring(hex.length - 4).toUpperCase()}';
}

/// Automatically scans for and connects to the BLE device associated with
/// [deviceId] whenever the connection is not already established.
///
/// Activated by reading [bleAutoConnectProvider] from the device detail screen.
/// Disposed (and BLE disconnected) when the screen is popped.
final bleAutoConnectProvider =
    Provider.autoDispose.family<void, String>((ref, deviceId) {
  final bleService = ref.watch(bleServiceProvider);
  final expectedName = bleNameFromDeviceId(deviceId);
  if (expectedName.isEmpty) return;

  StreamSubscription<DiscoveredVenaDevice>? scanSub;
  StreamSubscription<BleConnectionStatus>? connSub;
  bool disposed = false;

  void startScan() {
    if (disposed) return;
    if (bleService.currentStatus == BleConnectionStatus.connected) return;

    debugPrint('[BLE AutoConnect] scanning for $expectedName');
    scanSub?.cancel();

    scanSub = bleService
        .scanForVenaDevices(timeout: const Duration(seconds: 15))
        .where((d) => d.name == expectedName)
        .listen(
      (device) {
        if (disposed) return;
        scanSub?.cancel();
        debugPrint('[BLE AutoConnect] found $expectedName (${device.bleId}), connecting…');
        bleService.connectToDevice(device.bleId);
      },
      onDone: () {
        if (!disposed &&
            bleService.currentStatus != BleConnectionStatus.connected) {
          debugPrint('[BLE AutoConnect] scan done without finding device, retrying in 5s');
          Future<void>.delayed(const Duration(seconds: 5), startScan);
        }
      },
      onError: (e) => debugPrint('[BLE AutoConnect] scan error: $e'),
    );
  }

  // Retry scan on disconnect.
  connSub = bleService.connectionState.listen((status) {
    if (disposed) return;
    if (status == BleConnectionStatus.disconnected) {
      debugPrint('[BLE AutoConnect] disconnected, retrying in 3s');
      Future<void>.delayed(const Duration(seconds: 3), startScan);
    }
  });

  startScan();

  ref.onDispose(() {
    disposed = true;
    scanSub?.cancel();
    connSub?.cancel();
    bleService.stopScan();
    bleService.disconnectDevice();
    debugPrint('[BLE AutoConnect] disposed, BLE disconnected');
  });
});
