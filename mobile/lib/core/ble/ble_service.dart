import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'ble_models.dart';
import 'ble_uuids.dart';

/// Wraps [FlutterReactiveBle] with Vena-specific GATT logic.
///
/// Scans for devices advertising [BleUuids.serviceUuid], connects,
/// discovers services, subscribes to notifications, and provides a
/// broadcast stream of [BleTelemetry].
class BleService {
  BleService({FlutterReactiveBle? ble}) : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;

  String? _connectedDeviceId;
  String? _logicalDeviceId; // Vena device ID (from device_info char)

  final _telemetryController = StreamController<BleTelemetry>.broadcast();
  final _stateController = StreamController<BleConnectionStatus>.broadcast();

  /// Parsed telemetry from BLE notifications.
  Stream<BleTelemetry> get onTelemetry => _telemetryController.stream;

  /// Connection state changes.
  Stream<BleConnectionStatus> get connectionState => _stateController.stream;

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleConnectionStatus get currentStatus => _status;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Scans for Vena BLE devices. Returns discovered devices via callback.
  void startScan({
    required void Function(DiscoveredDevice) onDeviceFound,
    Duration timeout = const Duration(seconds: 10),
  }) {
    _scanSub?.cancel();
    _emitState(BleConnectionStatus.scanning);

    final serviceId = Uuid.parse(BleUuids.serviceUuid);
    _scanSub = _ble
        .scanForDevices(withServices: [serviceId], scanMode: ScanMode.lowLatency)
        .timeout(timeout, onTimeout: (sink) => sink.close())
        .listen(
      onDeviceFound,
      onDone: () {
        if (_status == BleConnectionStatus.scanning) {
          _emitState(BleConnectionStatus.disconnected);
        }
      },
      onError: (e) => debugPrint('[BLE] scan error: $e'),
    );
  }

  /// Scans for Vena BLE devices, returning a stream of [DiscoveredVenaDevice].
  /// Filtered by service UUID; devices are further filtered by `Vena-` prefix.
  Stream<DiscoveredVenaDevice> scanForVenaDevices({
    Duration timeout = const Duration(seconds: 15),
  }) {
    _emitState(BleConnectionStatus.scanning);
    final serviceId = Uuid.parse(BleUuids.serviceUuid);
    return _ble
        .scanForDevices(withServices: [serviceId], scanMode: ScanMode.lowLatency)
        .timeout(timeout, onTimeout: (sink) => sink.close())
        .map((d) => DiscoveredVenaDevice(bleId: d.id, name: d.name, rssi: d.rssi));
  }

  /// Stops an ongoing scan.
  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    if (_status == BleConnectionStatus.scanning) {
      _emitState(BleConnectionStatus.disconnected);
    }
  }

  /// Connects to a specific BLE device by its platform ID.
  void connectToDevice(String bleDeviceId) {
    _connectionSub?.cancel();
    _emitState(BleConnectionStatus.connecting);

    _connectionSub = _ble
        .connectToDevice(
      id: bleDeviceId,
      connectionTimeout: const Duration(seconds: 10),
    )
        .listen(
      (update) async {
        switch (update.connectionState) {
          case DeviceConnectionState.connected:
            _connectedDeviceId = bleDeviceId;
            _emitState(BleConnectionStatus.connected);
            await _onConnected(bleDeviceId);
          case DeviceConnectionState.disconnected:
            _connectedDeviceId = null;
            _emitState(BleConnectionStatus.disconnected);
          default:
            break;
        }
      },
      onError: (e) {
        debugPrint('[BLE] connection error: $e');
        _emitState(BleConnectionStatus.disconnected);
      },
    );
  }

  /// Disconnects from the current device.
  Future<void> disconnectDevice() async {
    _notifySub?.cancel();
    _notifySub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _connectedDeviceId = null;
    _emitState(BleConnectionStatus.disconnected);
  }

  /// Reads the device_info characteristic (JSON with device_id).
  Future<String?> readDeviceId() async {
    if (_connectedDeviceId == null) return null;
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(BleUuids.serviceUuid),
        characteristicId: Uuid.parse(BleUuids.deviceInfoChar),
        deviceId: _connectedDeviceId!,
      );
      final bytes = await _ble.readCharacteristic(char);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      _logicalDeviceId = json['device_id'] as String?;
      return _logicalDeviceId;
    } catch (e) {
      debugPrint('[BLE] read device_info error: $e');
      return null;
    }
  }

  /// Sends Wi-Fi credentials + optional JWT to the provisioning characteristic.
  Future<bool> provisionWifi(BleWifiCredentials creds) async {
    if (_connectedDeviceId == null) {
      debugPrint('[BLE] provision write error: not connected (_connectedDeviceId is null)');
      return false;
    }
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(BleUuids.serviceUuid),
        characteristicId: Uuid.parse(BleUuids.wifiProvisioningChar),
        deviceId: _connectedDeviceId!,
      );
      final payload = utf8.encode(jsonEncode(creds.toJson()));
      debugPrint('[BLE] provision write: ${payload.length} bytes to ${_connectedDeviceId}');
      await _ble.writeCharacteristicWithResponse(char, value: payload);
      debugPrint('[BLE] provision write: success');
      return true;
    } catch (e) {
      debugPrint('[BLE] provision write error: $e');
      return false;
    }
  }

  /// Reads the pairing code characteristic.
  Future<String?> readPairingCode() async {
    if (_connectedDeviceId == null) return null;
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(BleUuids.serviceUuid),
        characteristicId: Uuid.parse(BleUuids.pairingCodeChar),
        deviceId: _connectedDeviceId!,
      );
      final bytes = await _ble.readCharacteristic(char);
      return utf8.decode(bytes).trim();
    } catch (e) {
      debugPrint('[BLE] read pairing code error: $e');
      return null;
    }
  }

  /// Reads the wifi_status characteristic.
  Future<BleWifiStatus?> readWifiStatus() async {
    if (_connectedDeviceId == null) return null;
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(BleUuids.serviceUuid),
        characteristicId: Uuid.parse(BleUuids.wifiStatusChar),
        deviceId: _connectedDeviceId!,
      );
      final bytes = await _ble.readCharacteristic(char);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return BleWifiStatus.fromJson(json);
    } catch (e) {
      debugPrint('[BLE] read wifi_status error: $e');
      return null;
    }
  }

  /// Releases all resources.
  void dispose() {
    _scanSub?.cancel();
    _notifySub?.cancel();
    _connectionSub?.cancel();
    _telemetryController.close();
    _stateController.close();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _onConnected(String bleDeviceId) async {
    // Read device ID first
    await readDeviceId();

    // Subscribe to live telemetry notifications
    final telemetryChar = QualifiedCharacteristic(
      serviceId: Uuid.parse(BleUuids.serviceUuid),
      characteristicId: Uuid.parse(BleUuids.liveTelemetryChar),
      deviceId: bleDeviceId,
    );

    _notifySub?.cancel();
    _notifySub = _ble.subscribeToCharacteristic(telemetryChar).listen(
      (bytes) {
        try {
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          final deviceId = _logicalDeviceId ?? bleDeviceId;
          final telemetry = BleTelemetry.fromJson(deviceId, json);
          if (!_telemetryController.isClosed) {
            _telemetryController.add(telemetry);
          }
        } catch (e) {
          debugPrint('[BLE] telemetry parse error: $e');
        }
      },
      onError: (e) => debugPrint('[BLE] notify error: $e'),
    );
  }

  void _emitState(BleConnectionStatus status) {
    _status = status;
    if (!_stateController.isClosed) _stateController.add(status);
  }
}
