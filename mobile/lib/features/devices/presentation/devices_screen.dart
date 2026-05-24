// I1 — DevicesScreen: "Minhas Venas" list.
//
// Data flows exclusively from Drift (offline-first):
//   REST / MQTT  →  Drift  →  devicesProvider  →  DeviceCard
//
// Pull-to-refresh triggers DeviceSyncService.syncDeviceList() which fetches
// GET /devices from the backend and upserts results into Drift.
//
// The FAB navigates to /devices/pair (Phase 13).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/device_sync_service.dart';
import '../../../core/theme/colors.dart';
import '../../../design_system/components/empty_state.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import '../application/devices_provider.dart';
import 'device_card.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: VenaColors.background,
      appBar: AppBar(
        backgroundColor: VenaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Minhas Venas', style: VenaTypography.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/devices/pair'),
        backgroundColor: VenaColors.primary,
        foregroundColor: VenaColors.onPrimary,
        tooltip: 'Parear novo dispositivo',
        child: const Icon(Icons.add),
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Erro ao carregar dispositivos.',
            style: VenaTypography.bodyMedium,
          ),
        ),
        data: (deviceList) {
          if (deviceList.isEmpty) {
            return EmptyState(
              title: 'Nenhuma Vena pareada',
              subtitle:
                  'Escaneie o QR code no dispositivo para começar.',
              icon: Icons.sensors_off_outlined,
              actionLabel: 'Parear dispositivo',
              onAction: () => context.push('/devices/pair'),
            );
          }

          return RefreshIndicator(
            color: VenaColors.primary,
            onRefresh: () =>
                ref.read(deviceSyncServiceProvider).syncDeviceList(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: VenaSpacing.lg,
                vertical: VenaSpacing.lg,
              ),
              itemCount: deviceList.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: VenaSpacing.md),
              itemBuilder: (context, index) {
                final device = deviceList[index];
                return DeviceCard(
                  device: device,
                  onTap: () => context.go('/devices/${device.deviceId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
