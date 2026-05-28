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
import 'package:flutter/services.dart';
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
import 'edit_device_bottom_sheet.dart';

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

    final card = VenaCard(
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showEditDeviceSheet(context, device);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: name + connection badge ──────────────────────────
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

          // ── Right: ambient temperature ─────────────────────────────
          MetricTile(
            value: latest?.ambientT,
            unit: '°C',
            label: 'Temp.',
            isLoading: latestAsync.isLoading,
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

    if (device.storedContent == null || device.storedContent!.isEmpty) {
      return card;
    }

    // Dot sits on top of the card at the bottom-right, inside the card padding.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          bottom: 8,
          right: 10,
          child: _ContentDot(content: device.storedContent!),
        ),
      ],
    );
  }
}

/// Small circle in the bottom-right of the card indicating stored content.
class _ContentDot extends StatelessWidget {
  const _ContentDot({required this.content});

  final String content;

  Color _colorFor(String label) => switch (label.toLowerCase()) {
        'cacau' => const Color(0xFF6B4226),
        'pimenta-do-reino' => const Color(0xFF2C2C2C),
        _ => const Color(0xFF6C6B5C),
      };

  IconData _iconFor(String label) => switch (label.toLowerCase()) {
        'cacau' => Icons.spa_outlined,
        'pimenta-do-reino' => Icons.scatter_plot,
        _ => Icons.inventory_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(content);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(_iconFor(content), size: 12, color: Colors.white),
    );
  }
}
