import 'dart:async';

import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/core/ble/ble_permission_handler.dart';
import 'package:vena_app/core/ble/ble_service.dart';

// ── Mock classes ────────────────────────────────────────────────────────────

class MockBleService extends Mock implements BleService {
  final _telemetryController = StreamController<BleTelemetry>.broadcast();
  final _stateController = StreamController<BleConnectionStatus>.broadcast();

  @override
  Stream<BleTelemetry> get onTelemetry => _telemetryController.stream;

  @override
  Stream<BleConnectionStatus> get connectionState => _stateController.stream;

  @override
  BleConnectionStatus get currentStatus => BleConnectionStatus.disconnected;

  void emitTelemetry(BleTelemetry t) => _telemetryController.add(t);
  void emitState(BleConnectionStatus s) => _stateController.add(s);

  void disposeMock() {
    _telemetryController.close();
    _stateController.close();
  }
}

class MockBlePermissionHandler extends Mock implements BlePermissionHandler {}

// ── Fake data ───────────────────────────────────────────────────────────────

BleTelemetry fakeBleTelementry({
  String deviceId = 'dev1',
  double? ambientT = 22.5,
  double? ambientH = 65.0,
  double? setpoint = 22.0,
}) =>
    BleTelemetry(
      deviceId: deviceId,
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ambientT: ambientT,
      ambientH: ambientH,
      dissT: null,
      dissH: null,
      setpoint: setpoint,
      pidOut: null,
    );

const fakeBleWifiCredentials = BleWifiCredentials(
  ssid: 'TestNetwork',
  password: 'secret123',
  jwt: 'eyJhbGciOiJIUzI1NiJ9.test.sig',
);
