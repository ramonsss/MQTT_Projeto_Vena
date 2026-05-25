// L2 — PairingProvider: BLE-enabled pairing wizard state machine.
//
// Steps:
//   idle → confirming → bleScan → bleConnecting
//         → provisioning (if device lacks Wi-Fi)
//         → claiming → naming → success | error

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ble/ble_models.dart';
import '../../../core/ble/ble_provider.dart';
import '../../../core/sync/device_sync_service.dart';
import '../../devices/application/device_actions_provider.dart';
import 'provisioning_service.dart';

part 'pairing_provider.g.dart';

enum PairingStep {
  idle,
  confirming,
  bleScan,
  bleConnecting,
  provisioning,
  claiming,
  naming,
  success,
  error,
}

class PairingState {
  const PairingState({
    this.step = PairingStep.idle,
    this.deviceId,
    this.pairingCode,
    this.alias = '',
    this.errorMessage,
    this.discoveredDevices = const [],
    this.selectedBleDeviceId,
    this.selectedBleDeviceName,
  });

  final PairingStep step;
  final String? deviceId;
  final String? pairingCode;
  final String alias;
  final String? errorMessage;
  final List<DiscoveredVenaDevice> discoveredDevices;
  final String? selectedBleDeviceId;
  final String? selectedBleDeviceName;

  PairingState copyWith({
    PairingStep? step,
    String? deviceId,
    String? pairingCode,
    String? alias,
    String? errorMessage,
    List<DiscoveredVenaDevice>? discoveredDevices,
    String? selectedBleDeviceId,
    String? selectedBleDeviceName,
  }) =>
      PairingState(
        step: step ?? this.step,
        deviceId: deviceId ?? this.deviceId,
        pairingCode: pairingCode ?? this.pairingCode,
        alias: alias ?? this.alias,
        errorMessage: errorMessage,
        discoveredDevices: discoveredDevices ?? this.discoveredDevices,
        selectedBleDeviceId: selectedBleDeviceId ?? this.selectedBleDeviceId,
        selectedBleDeviceName:
            selectedBleDeviceName ?? this.selectedBleDeviceName,
      );
}

@riverpod
class PairingNotifier extends _$PairingNotifier {
  StreamSubscription<DiscoveredVenaDevice>? _scanSub;

  @override
  PairingState build() {
    final bleService = ref.read(bleServiceProvider);
    ref.onDispose(() {
      _scanSub?.cancel();
      bleService.stopScan();
    });
    return const PairingState();
  }

  // ── Step 1: QR ──────────────────────────────────────────────────────────

  void onQrDetected(String raw) {
    if (state.step != PairingStep.idle) return;
    final parsed = _parseQr(raw);
    if (parsed == null) {
      state = state.copyWith(
        step: PairingStep.error,
        errorMessage:
            'QR inválido. Aproxime a câmera do código no dispositivo.',
      );
      return;
    }
    state = state.copyWith(
      step: PairingStep.confirming,
      deviceId: parsed.$1,
      pairingCode: parsed.$2,
    );
  }

  // ── Step 2: BLE Scan ────────────────────────────────────────────────────

  void startBleScan() {
    state = state.copyWith(
      step: PairingStep.bleScan,
      discoveredDevices: [],
    );
    _scanSub?.cancel();
    _scanSub = ref
        .read(bleServiceProvider)
        .scanForVenaDevices(timeout: const Duration(seconds: 15))
        .listen(
      (device) {
        final updated = [
          ...state.discoveredDevices.where((d) => d.bleId != device.bleId),
          device,
        ]..sort((a, b) => b.rssi.compareTo(a.rssi));
        state = state.copyWith(discoveredDevices: updated);
      },
      onError: (e) {
        debugPrint('[Pairing] scan error: $e');
        state = state.copyWith(
          step: PairingStep.error,
          errorMessage:
              'Erro ao escanear. Verifique as permissões Bluetooth.',
        );
      },
    );
  }

  void retryBleScan() => startBleScan();

  // ── Step 3: BLE Connect ─────────────────────────────────────────────────

  Future<void> selectDevice(String bleDeviceId, String bleDeviceName) async {
    _scanSub?.cancel();
    _scanSub = null;
    ref.read(bleServiceProvider).stopScan();

    state = state.copyWith(
      step: PairingStep.bleConnecting,
      selectedBleDeviceId: bleDeviceId,
      selectedBleDeviceName: bleDeviceName,
    );

    final completer = Completer<void>();
    StreamSubscription? connSub;

    // Register listener BEFORE connect to avoid missing the event
    connSub = ref.read(bleServiceProvider).connectionState.listen((status) {
      if (completer.isCompleted) return;
      if (status == BleConnectionStatus.connected) {
        connSub?.cancel();
        completer.complete();
      } else if (status == BleConnectionStatus.disconnected) {
        connSub?.cancel();
        completer.completeError(Exception('Connection failed'));
      }
    });

    ref.read(bleServiceProvider).connectToDevice(bleDeviceId);

    try {
      await completer.future.timeout(const Duration(seconds: 15));

      final wifiStatus =
          await ref.read(bleServiceProvider).readWifiStatus();

      if (wifiStatus?.connected == true) {
        await _doClaim();
      } else {
        state = state.copyWith(step: PairingStep.provisioning);
      }
    } catch (e) {
      debugPrint('[Pairing] connect error: $e');
      state = state.copyWith(
        step: PairingStep.error,
        errorMessage:
            'Falha ao conectar. Aproxime o dispositivo e tente novamente.',
      );
    }
  }

  // ── Step 4: Wi-Fi Provisioning ──────────────────────────────────────────

  Future<void> submitProvisioning(String ssid, String psk) async {
    final deviceId = state.deviceId;
    final pairingCode = state.pairingCode;
    if (deviceId == null || pairingCode == null) return;

    state = state.copyWith(step: PairingStep.claiming);
    try {
      await ref.read(provisioningServiceProvider).provisionDevice(
            deviceId: deviceId,
            pairingCode: pairingCode,
            ssid: ssid,
            psk: psk,
          );
      await _doClaim();
    } catch (e) {
      state = state.copyWith(
        step: PairingStep.error,
        errorMessage: _friendlyError(e),
      );
    }
  }

  Future<void> skipProvisioning() async => _doClaim();

  // ── Step 5: Claim ───────────────────────────────────────────────────────

  Future<void> _doClaim() async {
    final deviceId = state.deviceId;
    final pairingCode = state.pairingCode;
    if (deviceId == null || pairingCode == null) return;

    state = state.copyWith(step: PairingStep.claiming);
    try {
      await ref
          .read(deviceActionsProvider.notifier)
          .claimDevice(deviceId, pairingCode);
      state = state.copyWith(step: PairingStep.naming);
    } catch (e) {
      state = state.copyWith(
        step: PairingStep.error,
        errorMessage: _friendlyError(e),
      );
    }
  }

  // ── Step 6: Name ────────────────────────────────────────────────────────

  Future<void> finishWithAlias(String alias) async {
    final id = state.deviceId;
    if (id == null) return;
    if (alias.trim().isNotEmpty) {
      await ref
          .read(deviceActionsProvider.notifier)
          .renameDevice(id, alias.trim());
    }
    await ref
        .read(deviceSyncServiceProvider)
        .syncDeviceList()
        .catchError((_) {});
    state = state.copyWith(step: PairingStep.success, alias: alias.trim());
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  void reset() {
    _scanSub?.cancel();
    _scanSub = null;
    ref.read(bleServiceProvider).stopScan();
    unawaited(ref.read(bleServiceProvider).disconnectDevice());
    state = const PairingState();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  (String, String)? _parseQr(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'vena') {
      final deviceId =
          uri.host.isNotEmpty ? uri.host : uri.pathSegments.firstOrNull;
      final code = uri.queryParameters['code'];
      if (deviceId != null &&
          deviceId.isNotEmpty &&
          code != null &&
          code.isNotEmpty) {
        return (deviceId, code);
      }
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final id = decoded['device_id'] as String?;
        final code = decoded['pairing_code'] as String?;
        if (id != null &&
            id.isNotEmpty &&
            code != null &&
            code.isNotEmpty) {
          return (id, code);
        }
      }
    } catch (_) {}
    return null;
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) {
      return 'Dispositivo não conectou ao Wi-Fi a tempo. Verifique as credenciais.';
    }
    if (msg.contains('409') || msg.contains('conflict')) {
      return 'Este dispositivo já está pareado com outra conta.';
    }
    if (msg.contains('404')) {
      return 'Dispositivo não encontrado. Verifique o código QR.';
    }
    if (msg.contains('ble write')) {
      return 'Falha ao enviar credenciais via Bluetooth. Aproxime o dispositivo.';
    }
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return 'Sem conexão. Verifique a internet e tente novamente.';
    }
    return 'Erro ao parear dispositivo. Tente novamente.';
  }
}
