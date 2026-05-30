import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models/mqtt_credentials.dart';

class MqttApi {
  const MqttApi(this._dio);

  final Dio _dio;

  /// Requests a short-lived MQTT JWT from the backend.
  Future<MqttCredentials> getMqttCredentials() async {
    final response =
        await _dio.post<Map<String, dynamic>>('/mqtt/credentials');
    return MqttCredentials.fromJson(response.data!);
  }
}

final mqttApiProvider = Provider<MqttApi>((ref) {
  return MqttApi(ref.read(apiClientProvider));
});
