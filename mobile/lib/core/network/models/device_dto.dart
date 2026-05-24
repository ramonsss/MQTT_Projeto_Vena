import 'package:drift/drift.dart';

import '../../db/app_database.dart';

class DeviceDto {
  const DeviceDto({
    required this.deviceId,
    this.alias,
    this.status,
    this.lastSeenAt,
    this.fwVersion,
  });

  final String deviceId;
  final String? alias;
  final String? status;
  final int? lastSeenAt;
  final String? fwVersion;

  factory DeviceDto.fromJson(Map<String, dynamic> json) => DeviceDto(
        deviceId: json['device_id'] as String,
        alias: json['alias'] as String?,
        status: json['status'] as String?,
        lastSeenAt: json['last_seen_at'] as int?,
        fwVersion: json['fw_version'] as String?,
      );

  DevicesCompanion toCompanion() => DevicesCompanion.insert(
        deviceId: deviceId,
        alias: Value(alias ?? ''),
        status: Value(status ?? 'offline'),
        lastSeenAt: Value(lastSeenAt),
        fwVersion: Value(fwVersion),
      );
}
