// B7 — EmptyState: centred illustration + title + subtitle + optional CTA.
//
// Used on the devices list when no devices are paired yet, on the history
// screen when no data is available, etc.
//
// Example:
//   EmptyState(
//     title: 'Nenhuma Vena pareada',
//     subtitle: 'Escaneie o QR code no dispositivo para começar.',
//     actionLabel: 'Parear dispositivo',
//     onAction: () => context.push('/devices/pair'),
//   )

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../tokens.dart';
import '../typography.dart';
import 'vena_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.sensors_off_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Label for the CTA button. Shown only when [onAction] is also provided.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VenaSpacing.xxxl,
          vertical: VenaSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in a circular tinted container
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: VenaColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: VenaColors.primary,
              ),
            ),
            const SizedBox(height: VenaSpacing.xl),
            Text(
              title,
              style: VenaTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: VenaSpacing.sm),
              Text(
                subtitle!,
                style: VenaTypography.bodyMedium.copyWith(
                  color: VenaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: VenaSpacing.xxl),
              VenaButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
