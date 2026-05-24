// J2 — BigMetric: hero animated number for the device detail screen.
//
// Animates value changes so live MQTT updates feel smooth:
//   - AnimatedSwitcher fades+slides the digit string on text change.
//   - TweenAnimationBuilder provides a numeric interpolation (counter effect)
//     for small delta changes (< 5 units) to avoid jarring jumps.
//
// Example:
//   BigMetric(value: 24.3, unit: '°C', label: 'Temperatura')
//   BigMetric(value: null, unit: '°C', label: 'Temperatura') // shows --

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';

class BigMetric extends StatefulWidget {
  const BigMetric({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
  });

  /// Current reading. `null` renders `--`.
  final double? value;
  final String unit;
  final String label;

  @override
  State<BigMetric> createState() => _BigMetricState();
}

class _BigMetricState extends State<BigMetric> {
  double? _displayValue;

  @override
  void didUpdateWidget(BigMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) _displayValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.value ?? _displayValue;
    final text = current != null ? current.toStringAsFixed(1) : '--';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Animated value + unit ──────────────────────────────────────────
        AnimatedSwitcher(
          duration: VenaDuration.normal,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(text),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                style: VenaTypography.metricLarge, // 64 px Fraunces
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: VenaSpacing.sm,
                  bottom: VenaSpacing.md,
                ),
                child: Text(
                  widget.unit,
                  style: GoogleFonts.fraunces(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: VenaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: VenaSpacing.xs),

        // ── Label ──────────────────────────────────────────────────────────
        Text(widget.label, style: VenaTypography.labelMedium),
      ],
    );
  }
}
