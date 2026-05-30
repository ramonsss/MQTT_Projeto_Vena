// B4 — MetricTile: large tabular number + unit + label + optional delta.
//
// Animates value changes with a fade+slide transition so live updates
// feel smooth without being distracting.
//
// Example:
//   MetricTile(value: 24.3, unit: '°C', label: 'Temperatura', delta: -0.5)

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../tokens.dart';
import '../typography.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    this.delta,
    this.isLoading = false,
    this.metricStyle,
  });

  /// Current reading. Pass `null` to show `--` placeholder.
  final double? value;
  final String unit;
  final String label;

  /// Change since last reading (positive = rising, negative = falling).
  /// If `null`, the delta badge is hidden.
  final double? delta;

  final bool isLoading;

  /// Override the default [VenaTypography.metricMedium] style.
  final TextStyle? metricStyle;

  @override
  Widget build(BuildContext context) {
    final style = metricStyle ?? VenaTypography.metricMedium;
    final displayText =
        isLoading || value == null ? '--' : value!.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated value — triggers on every change to `displayText`.
            AnimatedSwitcher(
              duration: VenaDuration.normal,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: Text(
                displayText,
                key: ValueKey(displayText),
                style: style,
              ),
            ),
            const SizedBox(width: VenaSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: VenaSpacing.sm),
              child: Text(unit, style: VenaTypography.labelLarge),
            ),
          ],
        ),
        const SizedBox(height: VenaSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: VenaTypography.labelMedium),
            if (delta != null) ...[
              const SizedBox(width: VenaSpacing.sm),
              _DeltaBadge(delta: delta!),
            ],
          ],
        ),
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final color = isPositive ? VenaColors.tempLine : VenaColors.online;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 11,
          color: color,
        ),
        Text(
          delta.abs().toStringAsFixed(1),
          style: VenaTypography.labelSmall.copyWith(color: color),
        ),
      ],
    );
  }
}
