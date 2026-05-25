// J3 — MiniChart: compact 1-hour sparkline for a single variable.
//
// Shows the last [points] from telemetry_cache as a fl_chart LineChart.
// Single line with gradient fill. Used twice in the detail screen:
// once for temperature, once for humidity.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/theme/colors.dart';
import '../../../../design_system/typography.dart';

class MiniChart extends StatelessWidget {
  const MiniChart({
    super.key,
    required this.points,
    required this.valueGetter,
    required this.lineColor,
    required this.unit,
    this.label,
  });

  /// Cache rows from [TelemetryDao.getRecentCache], newest-first.
  final List<TelemetryCacheData> points;

  /// Extracts the value to plot from each cache row.
  final double? Function(TelemetryCacheData) valueGetter;

  /// Color for the line and gradient fill.
  final Color lineColor;

  /// Unit shown in tooltip (e.g. "°C" or "%").
  final String unit;

  /// Optional label for tooltip prefix.
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Center(
        child: Text(
          'Aguardando dados…',
          style: VenaTypography.bodySmall,
        ),
      );
    }

    // getRecentCache returns newest-first; reverse to oldest-first for chart.
    final ordered = points.reversed.toList();
    final minTs = ordered.first.ts.toDouble();

    final spots = <FlSpot>[];
    for (final p in ordered) {
      final y = valueGetter(p);
      if (y != null) {
        spots.add(FlSpot((p.ts - minTs) / 60000, y));
      }
    }

    if (spots.length < 2) {
      return Center(child: Text('Aguardando dados…', style: VenaTypography.bodySmall));
    }

    final allY = spots.map((s) => s.y);
    final minY = allY.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = allY.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxY - minY;

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.18),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: VenaColors.textSecondary.withValues(alpha: 0.12),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: range > 4 ? 2 : 1,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(0)}$unit',
                style: VenaTypography.labelSmall,
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                VenaColors.surfaceVariant.withValues(alpha: 0.92),
            getTooltipItems: (spots) => spots.map((s) {
              final prefix = label != null ? '${label!}\n' : '';
              return LineTooltipItem(
                '$prefix${s.y.toStringAsFixed(1)} $unit',
                VenaTypography.labelMedium.copyWith(color: lineColor),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
