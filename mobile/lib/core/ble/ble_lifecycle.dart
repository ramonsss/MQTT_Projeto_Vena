import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ble_service.dart';
import 'ble_provider.dart';

part 'ble_lifecycle.g.dart';

/// Manages BLE connection lifecycle based on app state.
///
/// - Foreground: resumes telemetry subscription (no action needed if connected).
/// - Background: starts a 30-second disconnect timer.
/// - Detached: immediately disconnects.
class BleLifecycleObserver with WidgetsBindingObserver {
  BleLifecycleObserver(this._service);

  final BleService _service;
  Timer? _disconnectTimer;

  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  void unregister() {
    _disconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _scheduleDisconnect();
      case AppLifecycleState.detached:
        _disconnectTimer?.cancel();
        _service.disconnectDevice();
      default:
        break;
    }
  }

  void _scheduleDisconnect() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(
      const Duration(seconds: 30),
      () => _service.disconnectDevice(),
    );
  }
}

/// Riverpod provider that registers the BLE lifecycle observer.
@Riverpod(keepAlive: true)
BleLifecycleObserver bleLifecycle(BleLifecycleRef ref) {
  final service = ref.read(bleServiceProvider);
  final observer = BleLifecycleObserver(service);
  observer.register();
  ref.onDispose(observer.unregister);
  return observer;
}
