// T9  — DeviceDetailScreen widget test:
//         Overrides latestStateProvider / recentCacheProvider directly to
//         avoid Drift streams (and their dispose-time timers) in widget tests.
//
// T10 — Stream-update test:
//         Uses a StreamController so the widget re-builds when a new
//         LatestState is pushed, verifying the reactive rendering pipeline.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/features/devices/application/devices_provider.dart';
import 'package:vena_app/features/live/application/live_telemetry_provider.dart';
import 'package:vena_app/features/live/presentation/device_detail_screen.dart';

// Minimal app wrapper — avoids go_router dependency in unit tests.
Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );

/// Builds a [LatestState] with sensible defaults for testing.
LatestState _state({
  double? ambientT,
  double? ambientH,
  double? setpoint,
  bool online = true,
}) =>
    LatestState(
      deviceId: 'dev1',
      ts: 1000,
      ambientT: ambientT,
      ambientH: ambientH,
      dissT: null,
      dissH: null,
      setpoint: setpoint,
      pidOut: null,
      source: 'mqtt',
      online: online,
    );

/// Standard provider overrides that inject a static [LatestState?] and an
/// empty cache list — no Drift stream, no pending timers.
List<Override> _staticOverrides(LatestState? latest) => [
      latestStateProvider('dev1')
          .overrideWith((ref) => Stream.value(latest)),
      recentCacheProvider('dev1')
          .overrideWith((ref) async => const <TelemetryCacheData>[]),
      connectionSourceProvider('dev1')
          .overrideWith((ref) => latest?.source ?? 'none'),
    ];

void main() {
  // ── T9: DeviceDetailScreen ─────────────────────────────────────────────
  group('T9 – DeviceDetailScreen', () {
    /// Pumps two frames so Riverpod delivers the async/stream values.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows placeholder when no telemetry received yet',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const DeviceDetailScreen(deviceId: 'dev1'),
              _staticOverrides(null)));
      await settle(tester);

      // BigMetric renders '--' when ambientT is null
      expect(find.textContaining('--'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows temperature value from latest_state', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceDetailScreen(deviceId: 'dev1'),
        _staticOverrides(_state(ambientT: 22.5, ambientH: 65.0, setpoint: 22.0)),
      ));
      await settle(tester);

      // BigMetric renders the temperature — text contains "22"
      expect(find.textContaining('22'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows humidity from sub-metrics row', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceDetailScreen(deviceId: 'dev1'),
        _staticOverrides(_state(ambientT: 20.0, ambientH: 70.0, setpoint: 20.0)),
      ));
      await settle(tester);

      expect(find.textContaining('70'), findsAtLeastNWidgets(1));
    });
  });

  // ── T10: Stream-update test ────────────────────────────────────────────
  group('T10 – DeviceDetailScreen rebuilds on new telemetry', () {
    testWidgets('widget shows new value after stream emits updated state',
        (tester) async {
      // Use a StreamController so we can push values on demand.
      final ctrl = StreamController<LatestState?>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(
        const DeviceDetailScreen(deviceId: 'dev1'),
        [
          latestStateProvider('dev1').overrideWith((ref) => ctrl.stream),
          recentCacheProvider('dev1')
              .overrideWith((ref) async => const <TelemetryCacheData>[]),
          connectionSourceProvider('dev1')
              .overrideWith((ref) => 'mqtt'),
        ],
      ));

      // Before any emission the stream is empty → placeholder
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('--'), findsAtLeastNWidgets(1));

      // Push a telemetry reading
      ctrl.add(_state(ambientT: 19.3, ambientH: 60.0, setpoint: 19.0));

      // Let Riverpod rebuild
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('19'), findsAtLeastNWidgets(1));
    });
  });
}
