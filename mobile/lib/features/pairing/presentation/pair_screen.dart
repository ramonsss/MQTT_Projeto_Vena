// L1 — PairScreen: BLE-enabled pairing wizard.
//
// Step 1 — Scan QR   : fullscreen MobileScanner
// Step 2 — Confirm   : show device_id + pairing_code
// Step 3 — BLE Scan  : list nearby Vena devices
// Step 4 — Connecting: progress indicator
// Step 5 — Provision : Wi-Fi credentials form (if needed)
// Step 6 — Claiming  : progress indicator
// Step 7 — Name      : optional alias → /devices

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../design_system/components/vena_button.dart';
import '../../../design_system/components/vena_card.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import '../application/pairing_provider.dart';
import '../../devices/application/devices_provider.dart';
import 'widgets/ble_scan_step.dart';
import 'widgets/pairing_success_step.dart';
import 'widgets/wifi_provision_step.dart';

/// When `true`, the QR scanner step is replaced by a button that simulates
/// a QR detection with fake data. Override in main_mock.dart.
final mockQrBypassProvider = Provider<bool>((_) => false);

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  late final MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pairingNotifierProvider);

    // Navigate away once pairing succeeds.
    ref.listen<PairingState>(pairingNotifierProvider, (_, next) {
      if (next.step == PairingStep.success) {
        ref.invalidate(devicesProvider);
        context.go('/devices');
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: state.step == PairingStep.idle,
      appBar: _buildAppBar(context, state),
      body: _buildBody(context, state),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context, PairingState state) {
    final transparent = state.step == PairingStep.idle;
    return AppBar(
      backgroundColor:
          transparent ? Colors.transparent : null,
      foregroundColor: transparent ? Colors.white : null,
      elevation: transparent ? 0 : null,
      title: Text(_titleFor(state.step)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (state.step == PairingStep.idle) {
            context.pop();
          } else {
            ref.read(pairingNotifierProvider.notifier).reset();
          }
        },
      ),
    );
  }

  String _titleFor(PairingStep step) => switch (step) {
        PairingStep.idle => 'Escanear dispositivo',
        PairingStep.confirming => 'Confirmar pareamento',
        PairingStep.bleScan => 'Buscar dispositivo',
        PairingStep.bleConnecting => 'Conectando...',
        PairingStep.provisioning => 'Configurar Wi-Fi',
        PairingStep.claiming => 'Pareando...',
        PairingStep.naming => 'Nomear dispositivo',
        PairingStep.success => 'Concluído',
        PairingStep.error => 'Erro',
      };

  // ── Body dispatcher ──────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, PairingState state) {
    final isMockQr = ref.watch(mockQrBypassProvider);

    return switch (state.step) {
      PairingStep.idle => isMockQr
          ? _MockScanStep(
              onDetect: (raw) =>
                  ref.read(pairingNotifierProvider.notifier).onQrDetected(raw),
            )
          : _ScanStep(
              controller: _scannerController,
              onDetect: (raw) =>
                  ref.read(pairingNotifierProvider.notifier).onQrDetected(raw),
            ),
      PairingStep.confirming => _ConfirmStep(
          deviceId: state.deviceId ?? '',
          pairingCode: state.pairingCode ?? '',
          onConfirm: () =>
              ref.read(pairingNotifierProvider.notifier).startBleScan(),
          onCancel: () =>
              ref.read(pairingNotifierProvider.notifier).reset(),
        ),
      PairingStep.bleScan => BleScanStep(
          devices: state.discoveredDevices,
          isScanning: true,
          onDeviceSelected: (d) => ref
              .read(pairingNotifierProvider.notifier)
              .selectDevice(d.bleId, d.name),
          onRetry: () =>
              ref.read(pairingNotifierProvider.notifier).retryBleScan(),
        ),
      PairingStep.bleConnecting => _LoadingStep(
          message:
              'Conectando a ${state.selectedBleDeviceName ?? "dispositivo"}...',
        ),
      PairingStep.provisioning => WifiProvisionStep(
          deviceName: state.selectedBleDeviceName ?? 'dispositivo',
          isLoading: false,
          onSubmit: (ssid, psk) => ref
              .read(pairingNotifierProvider.notifier)
              .submitProvisioning(ssid, psk),
          onSkip: () =>
              ref.read(pairingNotifierProvider.notifier).skipProvisioning(),
        ),
      PairingStep.claiming => const _LoadingStep(message: 'Pareando dispositivo...'),
      PairingStep.naming => PairingSuccessStep(
          onFinish: (alias, storedContent) => ref
              .read(pairingNotifierProvider.notifier)
              .finishWithAlias(alias, storedContent),
        ),
      PairingStep.success => const SizedBox.shrink(),
      PairingStep.error => _ErrorStep(
          message: state.errorMessage ?? 'Erro desconhecido. Tente novamente.',
          onRetry: () =>
              ref.read(pairingNotifierProvider.notifier).reset(),
        ),
    };
  }
}

// ── Step 1 — Scan ─────────────────────────────────────────────────────────────

class _ScanStep extends StatelessWidget {
  const _ScanStep({
    required this.controller,
    required this.onDetect,
  });

  final MobileScannerController controller;
  final ValueChanged<String> onDetect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera feed fills the entire screen.
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final raw = capture.barcodes.firstOrNull?.rawValue;
            if (raw != null && raw.isNotEmpty) onDetect(raw);
          },
          errorBuilder: (context, error, _) {
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(VenaSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined,
                      size: 64, color: Colors.white70),
                  const SizedBox(height: VenaSpacing.lg),
                  Text(
                    'Não foi possível iniciar a câmera.',
                    textAlign: TextAlign.center,
                    style: VenaTypography.headlineSmall
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: VenaSpacing.sm),
                  Text(
                    error.errorCode.toString(),
                    textAlign: TextAlign.center,
                    style: VenaTypography.bodySmall
                        .copyWith(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        ),
        // Dark overlay with centred cutout.
        _ScannerOverlay(),
        // Bottom instruction card.
        Positioned(
          left: VenaSpacing.lg,
          right: VenaSpacing.lg,
          bottom: VenaSpacing.xxxl + MediaQuery.of(context).padding.bottom,
          child: VenaCard(
            color: Colors.white.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(
              horizontal: VenaSpacing.xl,
              vertical: VenaSpacing.lg,
            ),
            child: Text(
              'Aponte para o QR code no rótulo do dispositivo Vena.',
              textAlign: TextAlign.center,
              style: VenaTypography.bodyMedium.copyWith(
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Semi-transparent overlay with a centred transparent square cutout.
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const cutout = 240.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cx = (w - cutout) / 2;
        final cy = (h - cutout) / 2;

        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                color: Colors.transparent,
                width: w,
                height: h,
              ),
              // Transparent rectangle = the "see-through" cutout.
              Positioned(
                left: cx,
                top: cy,
                child: Container(
                  width: cutout,
                  height: cutout,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(VenaRadius.md),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Step 2 — Confirm ─────────────────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.deviceId,
    required this.pairingCode,
    required this.onConfirm,
    required this.onCancel,
  });

  final String deviceId;
  final String pairingCode;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VenaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.devices, size: 64, color: Color(0xFF5F6C37)),
            const SizedBox(height: VenaSpacing.xxl),
            VenaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'ID do dispositivo', value: deviceId),
                  const SizedBox(height: VenaSpacing.md),
                  _InfoRow(label: 'Código de pareamento', value: pairingCode),
                ],
              ),
            ),
            const SizedBox(height: VenaSpacing.xl),
            VenaButton(
              label: 'Buscar via Bluetooth',
              onPressed: onConfirm,
            ),
            const SizedBox(height: VenaSpacing.md),
            VenaButton(
              label: 'Cancelar',
              variant: VenaButtonVariant.ghost,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VenaTypography.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: VenaSpacing.xs),
        Text(
          value,
          style: VenaTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: VenaSpacing.xl),
          Text(message,
              style: VenaTypography.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorStep extends StatelessWidget {
  const _ErrorStep({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VenaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: Color(0xFFB85C38)),
            const SizedBox(height: VenaSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: VenaTypography.bodyMedium,
            ),
            const SizedBox(height: VenaSpacing.xxl),
            VenaButton(label: 'Tentar novamente', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

// ── Mock scan step (used in main_mock to bypass camera) ───────────────────────

class _MockScanStep extends StatelessWidget {
  const _MockScanStep({required this.onDetect});

  final ValueChanged<String> onDetect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VenaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Color(0xFF5F6C37)),
            const SizedBox(height: VenaSpacing.xxl),
            Text(
              'Modo mock — câmera desabilitada.',
              textAlign: TextAlign.center,
              style: VenaTypography.bodyMedium,
            ),
            const SizedBox(height: VenaSpacing.xxxl),
            VenaButton(
              label: 'Simular QR detectado',
              onPressed: () => onDetect(
                'vena://vena-d0ef763235f4?code=8A4A-4AF1',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
