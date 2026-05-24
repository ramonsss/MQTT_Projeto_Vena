// I2 — DeviceCard: list card for a single Vena device.
//
// Reads [latestStateProvider] independently so each card updates only
// when *its own* device's telemetry changes — other cards stay idle.
//
// Layout:
//   ┌────────────────────────────────────────────┐
//   │  [Device name]              24.3  °C        │
//   │  ● Online                   Temp.           │
//   └────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../design_system/components/connection_badge.dart';
import '../../../design_system/components/metric_tile.dart';
import '../../../design_system/components/vena_card.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import '../application/devices_provider.dart';

class DeviceCard extends ConsumerWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestStateProvider(device.deviceId));
    final latest = latestAsync.valueOrNull;

    // Prefer live MQTT `online` flag; fall back to backend `status` field.
    final isOnline = latest?.online ?? (device.status == 'online');

    final displayName =
        device.alias.isNotEmpty ? device.alias : device.deviceId;

    return VenaCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: name + connection badge ─────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: VenaTypography.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: VenaSpacing.xs),
                ConnectionBadge(online: isOnline),
              ],
            ),
          ),

          const SizedBox(width: VenaSpacing.lg),

          // ── Right: ambient temperature ─────────────────────────────────
          MetricTile(
            value: latest?.ambientT,
            unit: '°C',
            label: 'Temp.',
            isLoading: latestAsync.isLoading,
            // Use a smaller style than the default metricMedium (40 px)
            // so the number fits comfortably inside a list card.
            metricStyle: GoogleFonts.fraunces(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.0,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: VenaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
