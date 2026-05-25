import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models/device_dto.dart';
import 'models/telemetry_point.dart';

class DeviceApi {
  const DeviceApi(this._dio);

  final Dio _dio;

  Future<List<DeviceDto>> listDevices() async {
    final response = await _dio.get<List<dynamic>>('/devices');
    return response.data!
        .map((e) => DeviceDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> claimDevice(String deviceId, String pairingCode) => _dio.post(
        '/devices/$deviceId/claim',
        data: {'pairing_code': pairingCode},
      );

  /// Validates pairing_code and returns a device JWT for BLE provisioning.
  Future<String> provisionDevice(String deviceId, String pairingCode) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/devices/provision',
      data: {'device_id': deviceId, 'pairing_code': pairingCode},
    );
    return response.data!['device_jwt'] as String;
  }

  Future<void> updateAlias(String deviceId, String alias) => _dio.patch(
        '/devices/$deviceId',
        data: {'alias': alias},
      );

  Future<List<TelemetryPoint>> getHistory(
    String deviceId, {
    required int start,
    required int end,
    int limit = 500,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/devices/$deviceId/history',
      queryParameters: {'start': start, 'end': end, 'limit': limit},
    );
    return response.data!
        .map((e) => TelemetryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final deviceApiProvider = Provider<DeviceApi>((ref) {
  return DeviceApi(ref.read(apiClientProvider));
});
