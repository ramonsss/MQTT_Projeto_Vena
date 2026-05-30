import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/secure_token_storage.dart';
import '../network/mqtt_api.dart';
import 'mqtt_service.dart';

part 'mqtt_provider.g.dart';

/// Singleton [MqttService] — kept alive for the duration of the app session.
///
/// Initialise the full MQTT pipeline after login:
/// ```dart
/// ref.read(mqttMessageHandlerProvider); // wires message → DB
/// ref.read(mqttLifecycleProvider);      // registers app-lifecycle observer
/// await ref.read(mqttServiceProvider).connect();
/// ```
@Riverpod(keepAlive: true)
MqttService mqttService(MqttServiceRef ref) {
  final service = MqttService(
    mqttApi: ref.read(mqttApiProvider),
    storage: ref.read(secureTokenStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Stream of MQTT connection status — auto-disposes when not watched.
@riverpod
Stream<VenaMqttStatus> mqttStatus(MqttStatusRef ref) {
  return ref.watch(mqttServiceProvider).connectionState;
}
