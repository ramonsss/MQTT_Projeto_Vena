// Deviation indicator: shows the delta between ambient temp and setpoint.
//
// Renders: colored arrow (↑ above / ↓ below) + signed delta + textual status.
// Color coding:
//   - Green : within ±1°C of target
//   - Yellow: ±1–3°C deviation
//   - Red   : >3°C deviation
//
// If either value is null, shows a subtle "—" placeholder.

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../design_system/components/vena_card.dart';
import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';

class DeviationIndicator extends StatelessWidget {
  const DeviationIndicator({
    super.key,
    required this.ambientT,
    required this.setpoint,
  });

  final double? ambientT;
  final double? setpoint;

  @override
  Widget build(BuildContext context) {
    if (ambientT == null || setpoint == null) {
      return VenaCard(
        padding: const EdgeInsets.symmetric(
          horizontal: VenaSpacing.xl,
          vertical: VenaSpacing.lg,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thermostat_outlined,
                color: Colors.grey, size: 20),
            const SizedBox(width: VenaSpacing.sm),
            Text(
              'Aguardando leitura…',
              style: VenaTypography.bodyMedium.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final delta = ambientT! - setpoint!;
    final absDelta = delta.abs();

    // Determine severity.
    final _Severity severity;
    if (absDelta <= 1.0) {
      severity = _Severity.ok;
    } else if (absDelta <= 3.0) {
      severity = _Severity.warning;
    } else {
      severity = _Severity.critical;
    }

    final color = switch (severity) {
      _Severity.ok => VenaColors.humidityLine,
      _Severity.warning => const Color(0xFFE5A100),
      _Severity.critical => const Color(0xFFBF3922),
    };

    final icon = delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final sign = delta > 0 ? '+' : '';

    final statusText = switch (severity) {
      _Severity.ok => 'Dentro da faixa ideal',
      _Severity.warning => delta > 0
          ? 'Levemente acima da meta'
          : 'Levemente abaixo da meta',
      _Severity.critical => delta > 0
          ? 'Acima da temperatura alvo'
          : 'Abaixo da temperatura alvo',
    };

    return VenaCard(
      color: color,
      padding: const EdgeInsets.symmetric(
        horizontal: VenaSpacing.xl,
        vertical: VenaSpacing.lg,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(VenaRadius.md),
            ),
            child: Icon(
              absDelta <= 0.5 ? Icons.check_rounded : icon,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: VenaSpacing.lg),

          // Delta value + status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sign${delta.toStringAsFixed(1)} °C',
                  style: VenaTypography.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: VenaTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),
              ],
            ),
          ),

          // Setpoint reference
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Alvo',
                style: VenaTypography.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
              Text(
                '${setpoint!.toStringAsFixed(1)} °C',
                style: VenaTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Severity { ok, warning, critical }
