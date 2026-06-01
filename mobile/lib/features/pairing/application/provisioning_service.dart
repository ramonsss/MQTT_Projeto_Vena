import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ble/ble_models.dart';
import '../../../core/ble/ble_provider.dart';
import '../../../core/ble/ble_service.dart';
import '../../../core/network/device_api.dart';

part 'provisioning_service.g.dart';

/// Orchestrates the BLE Wi-Fi provisioning flow:
///   1. `POST /devices/provision` → receives `device_jwt`
///   2. Writes `{ssid, psk, jwt}` to BLE `wifi_provisioning` characteristic
///   3. Polls `wifi_status` until ESP32 is connected (timeout 30s)
class ProvisioningService {
  const ProvisioningService({
    required DeviceApi deviceApi,
    required BleService bleService,
  })  : _deviceApi = deviceApi,
        _bleService = bleService;

  final DeviceApi _deviceApi;
  final BleService _bleService;

  /// Returns `true` when the ESP32 successfully connects to Wi-Fi.
  /// Throws on backend error, BLE write failure, or timeout.
  Future<bool> provisionDevice({
    required String deviceId,
    required String pairingCode,
    required String ssid,
    required String psk,
  }) async {
    // 1. Get device JWT from backend
    debugPrint('[Provisioning] step 1: POST /devices/provision deviceId=$deviceId');
    final deviceJwt = await _deviceApi.provisionDevice(deviceId, pairingCode);
    debugPrint('[Provisioning] step 1 ok: jwt received (${deviceJwt.length} chars)');

    // 2. Write credentials to BLE
    debugPrint('[Provisioning] step 2: BLE write wifi_provisioning ssid=$ssid');
    final creds = BleWifiCredentials(ssid: ssid, password: psk, jwt: deviceJwt);
    final written = await _bleService.provisionWifi(creds);
    debugPrint('[Provisioning] step 2 result: written=$written');
    if (!written) throw Exception('BLE write to wifi_provisioning failed');

    // 3. Poll wifi_status until connected (max 30s)
    debugPrint('[Provisioning] step 3: polling wifi_status (30s timeout)');
    int pollCount = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      pollCount++;
      BleWifiStatus? status;
      try {
        status = await _bleService.readWifiStatus();
      } catch (e) {
        debugPrint('[Provisioning] poll #$pollCount readWifiStatus error: $e');
      }
      debugPrint('[Provisioning] poll #$pollCount wifi_status: connected=${status?.connected} ssid=${status?.ssid} ip=${status?.ip}');
      if (status?.connected == true) {
        debugPrint('[Provisioning] step 3 ok: ESP32 connected to WiFi');
        return true;
      }
    }

    debugPrint('[Provisioning] step 3 TIMEOUT after $pollCount polls');
    throw TimeoutException(
      'Device did not connect to Wi-Fi within 30 seconds.',
    );
  }
}

@riverpod
ProvisioningService provisioningService(ProvisioningServiceRef ref) {
  return ProvisioningService(
    deviceApi: ref.read(deviceApiProvider),
    bleService: ref.read(bleServiceProvider),
  );
}
