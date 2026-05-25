// J1 — DeviceDetailScreen: immersive live telemetry view.
//
// Layout (top → bottom):
//   ┌──────────────────────────────────┐
//   │  AppBar: alias/id + badge         │
//   ├──────────────────────────────────┤
//   │  BigMetric — ambient temp (hero)  │
//   ├──────────────────────────────────┤
//   │  Sub-metrics row (3 tiles)        │
//   │    Humidity | Setpoint | PID out  │
//   ├──────────────────────────────────┤
//   │  "Última hora" label              │
//   │  MiniChart (fl_chart)             │
//   └──────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../design_system/components/connection_badge.dart';
import '../../../design_system/components/metric_tile.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import '../application/live_telemetry_provider.dart';
import 'widgets/big_metric.dart';
import 'widgets/deviation_indicator.dart';
import 'widgets/mini_chart.dart';

class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestStateProvider(deviceId));
    final cacheAsync = ref.watch(recentCacheProvider(deviceId));
    final latest = latestAsync.valueOrNull;
    final isOnline = latest?.online ?? false;
    final source = ref.watch(connectionSourceProvider(deviceId));

    return Scaffold(
      backgroundColor: VenaColors.background,
      appBar: AppBar(
        backgroundColor: VenaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: VenaColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deviceId, style: VenaTypography.headlineSmall),
            const SizedBox(height: 2),
            ConnectionBadge(online: isOnline, source: source),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            color: VenaColors.textPrimary,
            tooltip: 'Histórico',
            onPressed: () => context.push('/devices/$deviceId/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: VenaSpacing.lg,
          vertical: VenaSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero: ambient temperature ────────────────────────────────
            Center(
              child: BigMetric(
                value: latest?.ambientT,
                unit: '°C',
                label: 'Temperatura Ambiente',
              ),
            ),

            const SizedBox(height: VenaSpacing.xxxl),

            // ── Sub-metrics ──────────────────────────────────────────────
            _SubMetricsRow(latest: latest),

            const SizedBox(height: VenaSpacing.xxl),

            // ── Deviation indicator ──────────────────────────────────────
            DeviationIndicator(
              ambientT: latest?.ambientT,
              setpoint: latest?.setpoint,
            ),

            const SizedBox(height: VenaSpacing.xxxl),

            // ── Mini-chart ───────────────────────────────────────────────
            _ChartSection(cacheAsync: cacheAsync),

            const SizedBox(height: VenaSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ── Sub-metrics row ────────────────────────────────────────────────────────

class _SubMetricsRow extends StatelessWidget {
  const _SubMetricsRow({required this.latest});

  final LatestState? latest;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        MetricTile(
          value: latest?.ambientH,
          unit: '%',
          label: 'Umidade',
        ),
        _Divider(),
        MetricTile(
          value: latest?.setpoint,
          unit: '°C',
          label: 'Temp. Alvo',
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 48,
        color: VenaColors.textSecondary.withValues(alpha: 0.15),
      );
}

// ── Chart section ──────────────────────────────────────────────────────────

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.cacheAsync});

  final AsyncValue<List<TelemetryCacheData>> cacheAsync;

  @override
  Widget build(BuildContext context) {
    return cacheAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text('Erro ao carregar gráfico.',
            style: VenaTypography.bodySmall),
      ),
      data: (points) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Temperature chart ──────────────────────────────────────
          _ChartLabel(
            color: VenaColors.tempLine,
            text: 'Temperatura °C',
            trailing: 'Última hora',
          ),
          const SizedBox(height: VenaSpacing.sm),
          SizedBox(
            height: 130,
            child: MiniChart(
              points: points,
              valueGetter: (p) => p.ambientT,
              lineColor: VenaColors.tempLine,
              unit: '°C',
              label: 'Temp.',
            ),
          ),

          const SizedBox(height: VenaSpacing.xxl),

          // ── Humidity chart ─────────────────────────────────────────
          _ChartLabel(
            color: VenaColors.humidityLine,
            text: 'Umidade %',
          ),
          const SizedBox(height: VenaSpacing.sm),
          SizedBox(
            height: 130,
            child: MiniChart(
              points: points,
              valueGetter: (p) => p.ambientH,
              lineColor: VenaColors.humidityLine,
              unit: '%',
              label: 'Umid.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLabel extends StatelessWidget {
  const _ChartLabel({
    required this.color,
    required this.text,
    this.trailing,
  });

  final Color color;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: VenaSpacing.xs),
        Text(text, style: VenaTypography.labelSmall),
        if (trailing != null) ...[
          const Spacer(),
          Text(trailing!, style: VenaTypography.labelSmall),
        ],
      ],
    );
  }
}
