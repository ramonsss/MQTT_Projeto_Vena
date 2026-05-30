/// BLE data models.

enum BleConnectionStatus { scanning, connecting, connected, disconnected }

/// A Vena device discovered during BLE scan.
class DiscoveredVenaDevice {
  const DiscoveredVenaDevice({
    required this.bleId,
    required this.name,
    required this.rssi,
  });

  final String bleId;
  final String name;
  final int rssi;
}

/// Parsed Wi-Fi status from the `wifi_status` BLE characteristic.
class BleWifiStatus {
  const BleWifiStatus({
    required this.connected,
    this.ssid,
    this.ip,
    this.rssi,
  });

  final bool connected;
  final String? ssid;
  final String? ip;
  final int? rssi;

  factory BleWifiStatus.fromJson(Map<String, dynamic> json) => BleWifiStatus(
        connected: json['connected'] as bool? ?? false,
        ssid: json['ssid'] as String?,
        ip: json['ip'] as String?,
        rssi: json['rssi'] as int?,
      );
}

/// Parsed live telemetry from BLE notify characteristic.
class BleTelemetry {
  const BleTelemetry({
    required this.deviceId,
    required this.ts,
    this.ambientT,
    this.ambientH,
    this.dissT,
    this.dissH,
    this.setpoint,
    this.pidOut,
  });

  final String deviceId;
  final int ts;
  final double? ambientT;
  final double? ambientH;
  final double? dissT;
  final double? dissH;
  final double? setpoint;
  final double? pidOut;

  factory BleTelemetry.fromJson(String deviceId, Map<String, dynamic> json) {
    return BleTelemetry(
      deviceId: deviceId,
      ts: json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ambientT: (json['ambient_t'] as num?)?.toDouble(),
      ambientH: (json['ambient_h'] as num?)?.toDouble(),
      dissT: (json['diss_t'] as num?)?.toDouble(),
      dissH: (json['diss_h'] as num?)?.toDouble(),
      setpoint: (json['setpoint'] as num?)?.toDouble(),
      pidOut: (json['pid_out'] as num?)?.toDouble(),
    );
  }
}

/// Wi-Fi credentials sent via BLE provisioning.
class BleWifiCredentials {
  const BleWifiCredentials({
    required this.ssid,
    required this.password,
    this.jwt,
  });

  final String ssid;
  final String password;
  final String? jwt;

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'psk': password,
        if (jwt != null) 'jwt': jwt,
      };
}
