// L2 — PairingProvider: manages the 3-step pairing wizard state.
//
// Steps:
//   1. idle       — waiting for QR scan
//   2. confirming — QR parsed, showing device_id + pairing_code for confirmation
//   3. claiming   — HTTP POST in progress
//   4. naming     — claim succeeded, user types optional alias
//   5. success    — device paired (and optionally renamed)
//   6. error      — claim failed

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/sync/device_sync_service.dart';
import '../../devices/application/device_actions_provider.dart';

part 'pairing_provider.g.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum PairingStep { idle, confirming, claiming, naming, success, error }

class PairingState {
  const PairingState({
    this.step = PairingStep.idle,
    this.deviceId,
    this.pairingCode,
    this.alias = '',
    this.errorMessage,
  });

  final PairingStep step;
  final String? deviceId;
  final String? pairingCode;
  final String alias;
  final String? errorMessage;

  PairingState copyWith({
    PairingStep? step,
    String? deviceId,
    String? pairingCode,
    String? alias,
    String? errorMessage,
  }) =>
      PairingState(
        step: step ?? this.step,
        deviceId: deviceId ?? this.deviceId,
        pairingCode: pairingCode ?? this.pairingCode,
        alias: alias ?? this.alias,
        errorMessage: errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// QR payload format (either is accepted):
///   • `vena://<deviceId>?code=<pairingCode>` (URI)
///   • `{"device_id":"...","pairing_code":"..."}` (JSON)
@riverpod
class PairingNotifier extends _$PairingNotifier {
  @override
  PairingState build() => const PairingState();

  // ── Step 1: parse QR ────────────────────────────────────────────────────

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

  // ── Step 2: confirm & claim ──────────────────────────────────────────────

  Future<void> confirmClaim() async {
    final id = state.deviceId;
    final code = state.pairingCode;
    if (id == null || code == null) return;

    state = state.copyWith(step: PairingStep.claiming);
    try {
      await ref.read(deviceActionsProvider.notifier).claimDevice(id, code);
      state = state.copyWith(step: PairingStep.naming);
    } catch (e) {
      state = state.copyWith(
        step: PairingStep.error,
        errorMessage: _friendlyError(e),
      );
    }
  }

  // ── Step 3: optional alias ───────────────────────────────────────────────

  Future<void> finishWithAlias(String alias) async {
    final id = state.deviceId;
    if (id == null) return;

    if (alias.trim().isNotEmpty) {
      await ref
          .read(deviceActionsProvider.notifier)
          .renameDevice(id, alias.trim());
    }
    // Best-effort final sync.
    await ref
        .read(deviceSyncServiceProvider)
        .syncDeviceList()
        .catchError((_) {});

    state = state.copyWith(step: PairingStep.success, alias: alias.trim());
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  void reset() => state = const PairingState();

  // ── Private helpers ──────────────────────────────────────────────────────

  (String, String)? _parseQr(String raw) {
    // URI format: vena://<deviceId>?code=<pairingCode>
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
    // JSON format
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
    if (msg.contains('409') || msg.contains('conflict')) {
      return 'Este dispositivo já está pareado com outra conta.';
    }
    if (msg.contains('404')) {
      return 'Dispositivo não encontrado. Verifique o código QR.';
    }
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return 'Sem conexão. Verifique a internet e tente novamente.';
    }
    return 'Erro ao parear dispositivo. Tente novamente.';
  }
}