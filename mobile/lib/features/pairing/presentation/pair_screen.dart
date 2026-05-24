// L1 — PairScreen: 3-step QR-pairing wizard.
//
// Step 1 — Scan  : fullscreen MobileScanner + overlay + instruction text
// Step 2 — Confirm: device_id + pairing_code preview → "Confirmar"
// Step 3 — Name  : optional alias field → "Salvar" → pop to /devices

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

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _aliasController = TextEditingController();
  final _aliasFocus = FocusNode();
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
    _aliasController.dispose();
    _aliasFocus.dispose();
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
      title: Text(
        state.step == PairingStep.idle
            ? 'Escanear dispositivo'
            : state.step == PairingStep.naming
                ? 'Nomear dispositivo'
                : 'Confirmar pareamento',
      ),
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

  // ── Body dispatcher ──────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, PairingState state) {
    return switch (state.step) {
      PairingStep.idle => _ScanStep(
          controller: _scannerController,
          onDetect: (raw) =>
              ref.read(pairingNotifierProvider.notifier).onQrDetected(raw),
        ),
      PairingStep.confirming || PairingStep.claiming => _ConfirmStep(
          deviceId: state.deviceId ?? '',
          pairingCode: state.pairingCode ?? '',
          isLoading: state.step == PairingStep.claiming,
          onConfirm: () =>
              ref.read(pairingNotifierProvider.notifier).confirmClaim(),
          onCancel: () =>
              ref.read(pairingNotifierProvider.notifier).reset(),
        ),
      PairingStep.naming => _NameStep(
          controller: _aliasController,
          focusNode: _aliasFocus,
          onSave: () => ref
              .read(pairingNotifierProvider.notifier)
              .finishWithAlias(_aliasController.text),
          onSkip: () => ref
              .read(pairingNotifierProvider.notifier)
              .finishWithAlias(''),
        ),
      PairingStep.error => _ErrorStep(
          message: state.errorMessage ??
              'Erro desconhecido. Tente novamente.',
          onRetry: () =>
              ref.read(pairingNotifierProvider.notifier).reset(),
        ),
      PairingStep.success => const SizedBox.shrink(),
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
    required this.isLoading,
    required this.onConfirm,
    required this.onCancel,
  });

  final String deviceId;
  final String pairingCode;
  final bool isLoading;
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
              label: 'Confirmar',
              isLoading: isLoading,
              onPressed: isLoading ? null : onConfirm,
            ),
            const SizedBox(height: VenaSpacing.md),
            VenaButton(
              label: 'Cancelar',
              variant: VenaButtonVariant.ghost,
              onPressed: isLoading ? null : onCancel,
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

// ── Step 3 — Name ─────────────────────────────────────────────────────────────

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onSkip,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VenaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: Color(0xFF5F6C37)),
            const SizedBox(height: VenaSpacing.md),
            Text(
              'Dispositivo pareado!',
              style: VenaTypography.headlineMedium,
            ),
            const SizedBox(height: VenaSpacing.sm),
            Text(
              'Dê um apelido ao dispositivo para identificá-lo facilmente.',
              textAlign: TextAlign.center,
              style: VenaTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VenaSpacing.xxl),
            TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Apelido (opcional)',
                hintText: 'Ex: Sala de fermentação',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VenaRadius.md),
                ),
              ),
              onSubmitted: (_) => onSave(),
            ),
            const SizedBox(height: VenaSpacing.xl),
            VenaButton(label: 'Salvar', onPressed: onSave),
            const SizedBox(height: VenaSpacing.md),
            VenaButton(
              label: 'Pular',
              variant: VenaButtonVariant.ghost,
              onPressed: onSkip,
            ),
          ],
        ),
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
