// E2 — BleScanStep: list of nearby Vena BLE devices with RSSI indicator.

import 'package:flutter/material.dart';

import '../../../../core/ble/ble_models.dart';
import '../../../../core/theme/colors.dart';
import '../../../../design_system/components/vena_button.dart';
import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';

class BleScanStep extends StatelessWidget {
  const BleScanStep({
    super.key,
    required this.devices,
    required this.onDeviceSelected,
    required this.onRetry,
    this.isScanning = true,
  });

  final List<DiscoveredVenaDevice> devices;
  final void Function(DiscoveredVenaDevice device) onDeviceSelected;
  final VoidCallback onRetry;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VenaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: VenaSpacing.xl),
          _Header(isScanning: isScanning, hasDevices: devices.isNotEmpty),
          const SizedBox(height: VenaSpacing.xxl),
          Expanded(
            child: devices.isEmpty
                ? _EmptyState(isScanning: isScanning, onRetry: onRetry)
                : _DeviceList(
                    devices: devices,
                    onDeviceSelected: onDeviceSelected,
                  ),
          ),
          if (!isScanning && devices.isEmpty) ...[
            const SizedBox(height: VenaSpacing.lg),
            VenaButton(label: 'Tentar novamente', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isScanning, required this.hasDevices});
  final bool isScanning;
  final bool hasDevices;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isScanning)
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
        else
          Icon(
            hasDevices ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
            size: 48,
            color: hasDevices ? VenaColors.primary : VenaColors.offline,
          ),
        const SizedBox(height: VenaSpacing.lg),
        Text(
          isScanning
              ? 'Buscando dispositivos Vena...'
              : hasDevices
                  ? 'Selecione o dispositivo'
                  : 'Nenhum dispositivo encontrado',
          style: VenaTypography.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: VenaSpacing.sm),
        Text(
          isScanning
              ? 'Aproxime o smartphone do dispositivo Vena.'
              : hasDevices
                  ? 'Toque no dispositivo para conectar.'
                  : 'Certifique-se de que o dispositivo está ligado e próximo.',
          style: VenaTypography.bodySmall
              .copyWith(color: VenaColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices, required this.onDeviceSelected});
  final List<DiscoveredVenaDevice> devices;
  final void Function(DiscoveredVenaDevice) onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: VenaSpacing.sm),
      itemBuilder: (context, i) {
        final d = devices[i];
        return _DeviceTile(device: d, onTap: () => onDeviceSelected(d));
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});
  final DiscoveredVenaDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(VenaRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VenaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VenaSpacing.lg,
            vertical: VenaSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.bluetooth, color: VenaColors.primary),
              const SizedBox(width: VenaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: VenaTypography.bodyMedium),
                    Text(
                      device.bleId,
                      style: VenaTypography.labelSmall
                          .copyWith(color: VenaColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _RssiIndicator(rssi: device.rssi),
            ],
          ),
        ),
      ),
    );
  }
}

class _RssiIndicator extends StatelessWidget {
  const _RssiIndicator({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) {
    final (bars, color) = switch (rssi) {
      > -60 => (3, VenaColors.online),
      > -80 => (2, VenaColors.warning),
      _ => (1, VenaColors.offline),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$rssi dBm',
          style: VenaTypography.labelSmall
              .copyWith(color: VenaColors.textSecondary),
        ),
        const SizedBox(width: VenaSpacing.xs),
        ...List.generate(
          3,
          (i) => Container(
            width: 4,
            height: 6.0 + i * 4,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: i < bars ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isScanning, required this.onRetry});
  final bool isScanning;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isScanning) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Verifique se o dispositivo está ligado e com Bluetooth ativo.',
            textAlign: TextAlign.center,
            style: VenaTypography.bodySmall
                .copyWith(color: VenaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
