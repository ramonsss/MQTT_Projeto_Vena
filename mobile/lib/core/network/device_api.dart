import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models/device_dto.dart';
import 'models/device_meta.dart';
import 'models/telemetry_point.dart';

class DeviceApi {
  const DeviceApi(this._dio);

  final Dio _dio;

  Future<List<DeviceDto>> listDevices() async {
    final response = await _dio.get<dynamic>('/devices');
    final data = response.data;
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map && data.containsKey('items')) {
      items = data['items'] as List<dynamic>;
    } else if (data is Map && data.containsKey('devices')) {
      items = data['devices'] as List<dynamic>;
    } else {
      throw Exception('GET /devices unexpected format: ${data.runtimeType} — $data');
    }
    return items
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

  /// Phase 5 — Adaptive-bucket history.
  ///
  /// When [range] is provided, calls the new aggregated endpoint
  /// (`/devices/{id}/history?range=...&bucket=...&metric=...`).
  /// When [start] / [end] are provided instead, uses the legacy raw-row path.
  ///
  /// Always returns the unwrapped `samples` array as `List<TelemetryPoint>`.
  /// Callers that need `bucket` / `range_start` / `range_end` should use
  /// [fetchHistoryResponse] instead.
  Future<List<TelemetryPoint>> getHistory(
    String deviceId, {
    String? range,
    String bucket = 'auto',
    String metric = 'all',
    int? start,
    int? end,
    int limit = 500,
  }) async {
    final resp = await fetchHistoryResponse(
      deviceId,
      range: range,
      bucket: bucket,
      metric: metric,
      start: start,
      end: end,
      limit: limit,
    );
    return resp.samples;
  }

  /// Same as [getHistory] but returns the full `HistoryResponse` envelope
  /// (with `bucket`, `range_start`, `range_end`).
  Future<HistoryResponse> fetchHistoryResponse(
    String deviceId, {
    String? range,
    String bucket = 'auto',
    String metric = 'all',
    int? start,
    int? end,
    int limit = 500,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (start != null || end != null) {
      if (start != null) query['start'] = start;
      if (end != null) query['end'] = end;
    } else {
      query['range'] = range ?? '24h';
      query['bucket'] = bucket;
      query['metric'] = metric;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/devices/$deviceId/history',
      queryParameters: query,
    );
    return HistoryResponse.fromJson(response.data!);
  }

  /// Phase 5 — last `meta` payload published by the ESP32.
  ///
  /// Returns `null` when the backend responds 404 (device never published).
  Future<DeviceMeta?> getMeta(String deviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/devices/$deviceId/meta',
      );
      return DeviceMeta.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

/// Envelope returned by `GET /devices/{id}/history`.
class HistoryResponse {
  const HistoryResponse({
    required this.deviceId,
    required this.count,
    required this.samples,
    this.bucket,
    this.rangeStart,
    this.rangeEnd,
  });

  final String deviceId;
  final int count;
  final List<TelemetryPoint> samples;
  final String? bucket;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  factory HistoryResponse.fromJson(Map<String, dynamic> json) => HistoryResponse(
        deviceId: json['device_id'] as String,
        count: (json['count'] as num).toInt(),
        samples: (json['samples'] as List<dynamic>)
            .map((e) => TelemetryPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        bucket: json['bucket'] as String?,
        rangeStart: json['range_start'] == null
            ? null
            : DateTime.parse(json['range_start'] as String),
        rangeEnd: json['range_end'] == null
            ? null
            : DateTime.parse(json['range_end'] as String),
      );
}

final deviceApiProvider = Provider<DeviceApi>((ref) {
  return DeviceApi(ref.read(apiClientProvider));
});

