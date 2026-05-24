import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_provider.dart';
import 'core/mqtt/mqtt_lifecycle.dart';
import 'core/mqtt/mqtt_message_handler.dart';
import 'core/mqtt/mqtt_provider.dart';
import 'core/sync/device_sync_service.dart';
import 'core/sync/outbox_worker.dart';
import 'core/theme/app_theme.dart';
import 'router/router.dart';

class VenaApp extends ConsumerWidget {
  const VenaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Dispara setup pós-login sempre que o estado de auth transita de
    // "não autenticado" para "autenticado" (login fresco ou token restaurado).
    ref.listen(authNotifierProvider, (prev, next) {
      final wasLoggedIn = prev?.valueOrNull != null;
      final isLoggedIn = next.valueOrNull != null;
      if (!wasLoggedIn && isLoggedIn) {
        unawaited(_postLoginSetup(ref));
      }
    });

    return MaterialApp.router(
      title: 'Vena',
      theme: VenaTheme.light(),
      darkTheme: VenaTheme.dark(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Inicializa os serviços que dependem de autenticação.
///
/// Chamado uma vez após login (novo ou restaurado do storage).
/// Erros são logados mas não propagados — o app funciona offline.
Future<void> _postLoginSetup(WidgetRef ref) async {
  // Instancia os singletons keepAlive (basta ler uma vez).
  ref.read(outboxWorkerProvider);
  ref.read(mqttLifecycleProvider);
  ref.read(mqttMessageHandlerProvider);

  // Sincroniza lista de devices do backend (best-effort).
  try {
    await ref.read(deviceSyncServiceProvider).syncDeviceList();
  } catch (e) {
    debugPrint('[PostLogin] sync falhou (será retentado no pull-to-refresh): $e');
  }

  // Conecta ao broker MQTT (reconexão automática gerenciada pelo MqttService).
  unawaited(ref.read(mqttServiceProvider).connect());
}

