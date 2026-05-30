// T9 — BleScanStep widget test:
//   • Shows scanning indicator when isScanning=true and devices is empty.
//   • Shows device list when devices are provided.
//   • Tapping a device calls onDeviceSelected with the correct device.
//   • Shows retry button when not scanning and no devices found.
//   • Calling onRetry invokes the callback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/core/ble/ble_models.dart';
import 'package:vena_app/features/pairing/presentation/widgets/ble_scan_step.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

DiscoveredVenaDevice _dev(String id, {int rssi = -60}) =>
    DiscoveredVenaDevice(bleId: id, name: 'Vena-$id', rssi: rssi);

void main() {
  group('T9 – BleScanStep', () {
    testWidgets('shows CircularProgressIndicator while scanning with no devices',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BleScanStep(
          devices: const [],
          onDeviceSelected: (_) {},
          onRetry: () {},
          isScanning: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Buscando dispositivos Vena...'), findsOneWidget);
    });

    testWidgets('shows device list when devices are available', (tester) async {
      final devices = [_dev('AA11'), _dev('BB22')];

      await tester.pumpWidget(_wrap(
        BleScanStep(
          devices: devices,
          onDeviceSelected: (_) {},
          onRetry: () {},
          isScanning: true,
        ),
      ));

      expect(find.text('Vena-AA11'), findsOneWidget);
      expect(find.text('Vena-BB22'), findsOneWidget);
    });

    testWidgets('tapping a device calls onDeviceSelected', (tester) async {
      DiscoveredVenaDevice? selected;
      final devices = [_dev('CC33')];

      await tester.pumpWidget(_wrap(
        BleScanStep(
          devices: devices,
          onDeviceSelected: (d) => selected = d,
          onRetry: () {},
          isScanning: false,
        ),
      ));

      await tester.tap(find.text('Vena-CC33'));
      await tester.pump();

      expect(selected?.bleId, 'CC33');
    });

    testWidgets('shows retry button when not scanning and no devices',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BleScanStep(
          devices: const [],
          onDeviceSelected: (_) {},
          onRetry: () {},
          isScanning: false,
        ),
      ));

      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Nenhum dispositivo encontrado'), findsOneWidget);
    });

    testWidgets('retry button calls onRetry callback', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(_wrap(
        BleScanStep(
          devices: const [],
          onDeviceSelected: (_) {},
          onRetry: () => retryCalled = true,
          isScanning: false,
        ),
      ));

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();

      expect(retryCalled, isTrue);
    });
  });
}
