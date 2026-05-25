// T10 — WifiProvisionStep widget test:
//   • SSID field is required — empty value shows validation error.
//   • PSK must be at least 8 characters.
//   • Valid form calls onSubmit with (ssid, psk).
//   • Shows CircularProgressIndicator when isLoading=true.
//   • Skip button calls onSkip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/features/pairing/presentation/widgets/wifi_provision_step.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('T10 – WifiProvisionStep', () {
    testWidgets('shows validation error when SSID is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        WifiProvisionStep(
          deviceName: 'Vena-A1B2',
          onSubmit: (_, __) {},
          onSkip: () {},
        ),
      ));

      // Tap submit with no input (button is last 'Configurar Wi-Fi' text)
      await tester.tap(find.text('Configurar Wi-Fi').last);
      await tester.pump();

      expect(find.text('Informe o nome da rede.'), findsOneWidget);
    });

    testWidgets('shows validation error when PSK is shorter than 8 chars',
        (tester) async {
      await tester.pumpWidget(_wrap(
        WifiProvisionStep(
          deviceName: 'Vena-A1B2',
          onSubmit: (_, __) {},
          onSkip: () {},
        ),
      ));

      await tester.enterText(find.byType(TextFormField).at(0), 'MyNetwork');
      await tester.enterText(find.byType(TextFormField).at(1), 'short');
      await tester.tap(find.text('Configurar Wi-Fi').last);
      await tester.pump();

      expect(
          find.text('A senha deve ter pelo menos 8 caracteres.'), findsOneWidget);
    });

    testWidgets('valid submission calls onSubmit with correct values',
        (tester) async {
      String? capturedSsid;
      String? capturedPsk;

      await tester.pumpWidget(_wrap(
        WifiProvisionStep(
          deviceName: 'Vena-A1B2',
          onSubmit: (ssid, psk) {
            capturedSsid = ssid;
            capturedPsk = psk;
          },
          onSkip: () {},
        ),
      ));

      await tester.enterText(find.byType(TextFormField).at(0), 'FazendaWifi');
      await tester.enterText(find.byType(TextFormField).at(1), 'senha1234');
      await tester.tap(find.text('Configurar Wi-Fi').last);
      await tester.pump();

      expect(capturedSsid, 'FazendaWifi');
      expect(capturedPsk, 'senha1234');
    });

    testWidgets('shows progress indicator when isLoading=true', (tester) async {
      await tester.pumpWidget(_wrap(
        WifiProvisionStep(
          deviceName: 'Vena-A1B2',
          onSubmit: (_, __) {},
          onSkip: () {},
          isLoading: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Submit button is hidden when loading (only the title Text remains)
      expect(find.text('Configurar Wi-Fi'), findsOneWidget);
    });

    testWidgets('skip button calls onSkip', (tester) async {
      var skipCalled = false;

      await tester.pumpWidget(_wrap(
        WifiProvisionStep(
          deviceName: 'Vena-A1B2',
          onSubmit: (_, __) {},
          onSkip: () => skipCalled = true,
        ),
      ));

      await tester.tap(find.textContaining('Pular'));
      await tester.pump();

      expect(skipCalled, isTrue);
    });
  });
}
