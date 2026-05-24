import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'mqtt_provider.dart';
import 'mqtt_service.dart';

part 'mqtt_lifecycle.g.dart';

/// Observes [AppLifecycleState] and drives MQTT connect/disconnect:
///
/// - `resumed`  → cancel pending background disconnect + reconnect.
/// - `paused`   → schedule disconnect after 30 s (saves battery & broker slots).
///
/// Activated by reading [mqttLifecycleProvider] after login.
class MqttLifecycleObserver with WidgetsBindingObserver {
  MqttLifecycleObserver(this._service);

  final MqttService _service;

  void register() => WidgetsBinding.instance.addObserver(this);
  void unregister() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _service.cancelBackgroundDisconnect();
        _service.connect(); // no-op if already connected
      case AppLifecycleState.paused:
        _service.scheduleBackgroundDisconnect();
      default:
        break;
    }
  }
}

/// Singleton lifecycle observer — registers with [WidgetsBinding] and
/// unregisters when the provider is disposed.
@Riverpod(keepAlive: true)
MqttLifecycleObserver mqttLifecycle(MqttLifecycleRef ref) {
  final observer = MqttLifecycleObserver(ref.read(mqttServiceProvider));
  observer.register();
  ref.onDispose(observer.unregister);
  return observer;
}
