// J3 — MiniChart: compact 1-hour sparkline for the device detail screen.
//
// Renders the last [points] rows from telemetry_cache as a fl_chart LineChart.
// Two lines: ambient temperature (terracotta) + dissolved temperature (olive).
// Gradient fill under each line gives the organic Vena aesthetic.
//
// If fewer than 2 data points are available, a placeholder is shown instead.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/theme/colors.dart';
import '../../../../design_system/typography.dart';

class MiniChart extends StatelessWidget {
  const MiniChart({
    super.key,
    required this.points,
  });

  /// Cache rows from [TelemetryDao.getRecentCache], newest-first.
  final List<TelemetryCacheData> points;

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

    // Convert ms timestamps → relative minutes from oldest point.
    List<FlSpot> toSpots(double? Function(TelemetryCacheData) getter) {
      final result = <FlSpot>[];
      for (final p in ordered) {
        final y = getter(p);
        if (y != null) {
          result.add(FlSpot((p.ts - minTs) / 60000, y));
        }
      }
      return result;
    }

    final ambientSpots = toSpots((p) => p.ambientT);
    final dissSpots = toSpots((p) => p.dissT);

    // Compute y-axis range with 1° padding.
    final allY = [
      ...ambientSpots.map((s) => s.y),
      ...dissSpots.map((s) => s.y),
    ];
    if (allY.isEmpty) {
      return Center(child: Text('Aguardando dados…', style: VenaTypography.bodySmall));
    }
    final minY = allY.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = allY.reduce((a, b) => a > b ? a : b) + 1;

    LineChartBarData buildLine(List<FlSpot> spots, Color color) =>
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        );

    return LineChart(
      LineChartData(
        lineBarsData: [
          buildLine(ambientSpots, VenaColors.tempLine),
          if (dissSpots.length >= 2) buildLine(dissSpots, VenaColors.humidityLine),
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
              interval: (maxY - minY) > 4 ? 2 : 1,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: VenaTypography.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                VenaColors.surfaceVariant.withValues(alpha: 0.92),
            getTooltipItems: (spots) => spots.map((s) {
              final color = s.bar.color ?? Colors.grey;
              final label =
                  s.barIndex == 0 ? 'Ambiente' : 'Dissolvida';
              return LineTooltipItem(
                '$label\n${s.y.toStringAsFixed(1)} °C',
                VenaTypography.labelMedium.copyWith(color: color),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
