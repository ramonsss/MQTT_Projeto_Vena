// K1 — HistoryScreen: full-screen telemetry chart with range selector.
//
// Layout:
//   AppBar  — device name + "Histórico"
//   Range chips — 24h / 7d / 30d (segmented selector)
//   Expanded chart area — HistoryChart (fl_chart)
//   Loading / error / empty states handled inline.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/typography.dart';
import '../application/history_provider.dart';
import 'widgets/history_chart.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryRange _range = HistoryRange.h24;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider(widget.deviceId, _range));

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
            Text(widget.deviceId, style: VenaTypography.headlineSmall),
            Text('Histórico', style: VenaTypography.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Range selector ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VenaSpacing.lg,
              vertical: VenaSpacing.md,
            ),
            child: Row(
              children: HistoryRange.values.map((r) {
                final selected = r == _range;
                return Padding(
                  padding: const EdgeInsets.only(right: VenaSpacing.sm),
                  child: ChoiceChip(
                    label: Text(r.label),
                    selected: selected,
                    onSelected: (_) {
                      if (!selected) setState(() => _range = r);
                    },
                    selectedColor: VenaColors.primary,
                    labelStyle: VenaTypography.labelMedium.copyWith(
                      color: selected
                          ? VenaColors.onPrimary
                          : VenaColors.textSecondary,
                    ),
                    backgroundColor: VenaColors.surfaceVariant,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(VenaRadius.full),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Chart ──────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                VenaSpacing.sm,
                VenaSpacing.sm,
                VenaSpacing.lg,
                VenaSpacing.lg,
              ),
              child: historyAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 40,
                        color: VenaColors.textSecondary,
                      ),
                      const SizedBox(height: VenaSpacing.md),
                      Text(
                        'Não foi possível carregar o histórico.',
                        style: VenaTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: VenaSpacing.md),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          historyProvider(widget.deviceId, _range),
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
                data: (points) => HistoryChart(
                  points: points,
                  range: _range,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
