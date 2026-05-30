/// Last `meta` payload published by an ESP32 (Phase 5).
///
/// Mirrors `GET /devices/{id}/meta` from the backend:
/// ```json
/// {
///   "device_id": "vena-...",
///   "payload": { "fw_version": "...", "free_heap_boot": 142336, ... },
///   "updated_at": "2026-05-23T12:00:00Z"
/// }
/// ```
class DeviceMeta {
  const DeviceMeta({
    required this.deviceId,
    required this.payload,
    required this.updatedAt,
  });

  final String deviceId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;

  // Convenience getters (all nullable — firmware versions may omit fields).
  String? get fwVersion => payload['fw_version'] as String?;
  int? get bleMaxConn => (payload['ble_max_conn'] as num?)?.toInt();
  int? get freeHeapBoot => (payload['free_heap_boot'] as num?)?.toInt();
  int? get freeHeapMinRuntime =>
      (payload['free_heap_min_runtime'] as num?)?.toInt();
  int? get wifiRssi => (payload['wifi_rssi'] as num?)?.toInt();
  bool? get ntpSynced => payload['ntp_synced'] as bool?;
  int? get bootCount => (payload['boot_count'] as num?)?.toInt();
  String? get lastResetReason => payload['last_reset_reason'] as String?;

  factory DeviceMeta.fromJson(Map<String, dynamic> json) => DeviceMeta(
        deviceId: json['device_id'] as String,
        payload: Map<String, dynamic>.from(
          json['payload'] as Map? ?? const {},
        ),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
