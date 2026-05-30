// K3 — HistoryChart: full-width fl_chart for the history screen.
//
// Renders ambient temperature (terracotta) and humidity (olive) with gradient fill.
// Tappable legend toggles each line's visibility.
// X-axis: time labels adapted to the selected range (hours or days).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/models/telemetry_point.dart';
import '../../../../core/theme/colors.dart';
import '../../../../design_system/tokens.dart';
import '../../../../design_system/typography.dart';
import '../../application/history_provider.dart';

class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.points,
    required this.range,
  });

  final List<TelemetryPoint> points;
  final HistoryRange range;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  bool _showTemp = true;
  bool _showHumidity = true;

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return Center(
        child: Text('Sem dados para este período.', style: VenaTypography.bodySmall),
      );
    }

    final points = widget.points;
    final minTs = points.first.ts.toDouble();
    final maxTs = points.last.ts.toDouble();

    // Build spots for temperature (avg/min/max).
    final tempSpots = <FlSpot>[];
    final tempMinSpots = <FlSpot>[];
    final tempMaxSpots = <FlSpot>[];
    for (final p in points) {
      if (p.ambientT != null) {
        tempSpots.add(FlSpot((p.ts - minTs).toDouble(), p.ambientT!));
      }
      if (p.hasAmbientBand) {
        tempMinSpots
            .add(FlSpot((p.ts - minTs).toDouble(), p.ambientTMin!));
        tempMaxSpots
            .add(FlSpot((p.ts - minTs).toDouble(), p.ambientTMax!));
      }
    }

    // Build spots for humidity (avg/min/max).
    final humSpots = <FlSpot>[];
    final humMinSpots = <FlSpot>[];
    final humMaxSpots = <FlSpot>[];
    for (final p in points) {
      if (p.ambientH != null) {
        humSpots.add(FlSpot((p.ts - minTs).toDouble(), p.ambientH!));
      }
      if (p.hasHumidityBand) {
        humMinSpots
            .add(FlSpot((p.ts - minTs).toDouble(), p.ambientHMin!));
        humMaxSpots
            .add(FlSpot((p.ts - minTs).toDouble(), p.ambientHMax!));
      }
    }

    if (tempSpots.length < 2 && humSpots.length < 2) {
      return Center(
        child: Text('Sem dados para este período.', style: VenaTypography.bodySmall),
      );
    }

    // Compute Y range from visible series (include min/max band when present).
    final visibleY = <double>[];
    if (_showTemp) {
      visibleY.addAll(tempSpots.map((s) => s.y));
      visibleY.addAll(tempMinSpots.map((s) => s.y));
      visibleY.addAll(tempMaxSpots.map((s) => s.y));
    }
    if (_showHumidity) {
      visibleY.addAll(humSpots.map((s) => s.y));
      visibleY.addAll(humMinSpots.map((s) => s.y));
      visibleY.addAll(humMaxSpots.map((s) => s.y));
    }
    if (visibleY.isEmpty) visibleY.addAll(tempSpots.map((s) => s.y));

    final minY = visibleY.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = visibleY.reduce((a, b) => a > b ? a : b) + 2;

    // X-axis format.
    final xFmt = widget.range == HistoryRange.h24
        ? DateFormat('HH:mm')
        : DateFormat('dd/MM');
    final totalSecs = maxTs - minTs;
    final xInterval = totalSecs > 0 ? totalSecs / 5 : 1.0;

    LineChartBarData buildLine(List<FlSpot> spots, Color color) =>
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        );

    /// Phase 5 — min/max band. Renders `_max` as an invisible line and
    /// fills the area DOWN to `_min` (cutOffY = belowBarSpotsVisible up to
    /// the min line) using fl_chart's "two-line band" pattern.
    List<LineChartBarData> buildBand(
      List<FlSpot> minSpots,
      List<FlSpot> maxSpots,
      Color color,
    ) {
      if (minSpots.length < 2 || maxSpots.length < 2) return const [];
      return [
        // Min line — invisible (just an anchor for the band's lower edge).
        LineChartBarData(
          spots: minSpots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: color.withValues(alpha: 0.0),
          barWidth: 0,
          dotData: const FlDotData(show: false),
        ),
        // Max line — invisible, filled down to the min line above via
        // belowBarData + applyCutOffY semantics.
        LineChartBarData(
          spots: maxSpots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: color.withValues(alpha: 0.0),
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.14),
            spotsLine: const BarAreaSpotsLine(show: false),
            cutOffY: 0,
            applyCutOffY: false,
          ),
        ),
      ];
    }

    final lineBars = <LineChartBarData>[];
    if (_showTemp) {
      lineBars.addAll(buildBand(tempMinSpots, tempMaxSpots, VenaColors.tempLine));
      if (tempSpots.length >= 2) {
        lineBars.add(buildLine(tempSpots, VenaColors.tempLine));
      }
    }
    if (_showHumidity) {
      lineBars.addAll(buildBand(humMinSpots, humMaxSpots, VenaColors.humidityLine));
      if (humSpots.length >= 2) {
        lineBars.add(buildLine(humSpots, VenaColors.humidityLine));
      }
    }

    return Column(
      children: [
        // ── Legend (tappable) ─────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendChip(
              color: VenaColors.tempLine,
              label: 'Temperatura °C',
              active: _showTemp,
              onTap: () => setState(() => _showTemp = !_showTemp),
            ),
            const SizedBox(width: VenaSpacing.md),
            _LegendChip(
              color: VenaColors.humidityLine,
              label: 'Umidade %',
              active: _showHumidity,
              onTap: () => setState(() => _showHumidity = !_showHumidity),
            ),
          ],
        ),
        const SizedBox(height: VenaSpacing.md),

        // ── Chart ────────────────────────────────────────────────────
        Expanded(
          child: lineBars.isEmpty
              ? Center(
                  child: Text('Selecione ao menos uma variável.',
                      style: VenaTypography.bodySmall),
                )
              : LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    lineBarsData: lineBars,
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
                            final dt =
                                DateTime.fromMillisecondsSinceEpoch(ts * 1000);
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(xFmt.format(dt),
                                  style: VenaTypography.labelSmall),
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
                          final dt =
                              DateTime.fromMillisecondsSinceEpoch(ts * 1000);
                          final timeFmt = widget.range == HistoryRange.h24
                              ? DateFormat('HH:mm')
                              : DateFormat('dd/MM HH:mm');
                          final color = s.bar.color ?? Colors.grey;
                          final isTemp = color == VenaColors.tempLine;
                          final unit = isTemp ? '°C' : '%';
                          final name = isTemp ? 'Temp.' : 'Umid.';
                          return LineTooltipItem(
                            '${timeFmt.format(dt)}\n$name ${s.y.toStringAsFixed(1)} $unit',
                            VenaTypography.labelMedium.copyWith(color: color),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Legend chip widget ──────────────────────────────────────────────────────

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 1.0 : 0.4,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: VenaTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}
