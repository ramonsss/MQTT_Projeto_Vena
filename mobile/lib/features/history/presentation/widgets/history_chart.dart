// K3 — HistoryChart: full-width fl_chart for the history screen.
//
// Renders ambient temperature (terracotta) with gradient fill.
// X-axis: time labels adapted to the selected range (hours or days).
// Y-axis: left side, minimal style.
// Touch: LineTouchData shows tooltip with formatted timestamp + value.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/models/telemetry_point.dart';
import '../../../../core/theme/colors.dart';
import '../../../../design_system/typography.dart';
import '../../application/history_provider.dart';

class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.points,
    required this.range,
  });

  final List<TelemetryPoint> points;
  final HistoryRange range;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Center(
        child: Text('Sem dados para este período.', style: VenaTypography.bodySmall),
      );
    }

    final minTs = points.first.ts.toDouble();
    final maxTs = points.last.ts.toDouble();

    // Build spots — skip points with null ambientT.
    final spots = <FlSpot>[];
    for (final p in points) {
      if (p.ambientT != null) {
        spots.add(FlSpot((p.ts - minTs).toDouble(), p.ambientT!));
      }
    }
    if (spots.length < 2) {
      return Center(
        child: Text('Sem dados para este período.', style: VenaTypography.bodySmall),
      );
    }

    final allY = spots.map((s) => s.y);
    final minY = allY.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = allY.reduce((a, b) => a > b ? a : b) + 1;

    // X-axis label format depends on range.
    final xFmt = range == HistoryRange.h24
        ? DateFormat('HH:mm')
        : DateFormat('dd/MM');

    // How many x-axis labels to show (avoid crowding).
    final totalSecs = (maxTs - minTs);
    final xInterval = totalSecs > 0 ? totalSecs / 5 : 1.0;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: VenaColors.tempLine,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  VenaColors.tempLine.withValues(alpha: 0.22),
                  VenaColors.tempLine.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
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
              reservedSize: 38,
              interval: (maxY - minY) > 6 ? 2 : 1,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: VenaTypography.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (v, meta) {
                final ts = (minTs + v).toInt();
                final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(xFmt.format(dt), style: VenaTypography.labelSmall),
                );
              },
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
                VenaColors.surfaceVariant.withValues(alpha: 0.95),
            getTooltipItems: (spots) => spots.map((s) {
              final ts = (minTs + s.x).toInt();
              final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
              final timeFmt = range == HistoryRange.h24
                  ? DateFormat('HH:mm')
                  : DateFormat('dd/MM HH:mm');
              return LineTooltipItem(
                '${timeFmt.format(dt)}\n${s.y.toStringAsFixed(1)} °C',
                VenaTypography.labelMedium.copyWith(color: VenaColors.tempLine),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
