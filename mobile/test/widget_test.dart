import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/app.dart';

void main() {
  testWidgets('VenaApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VenaApp()));
    await tester.pumpAndSettle();
    // Splash placeholder is the initial route — just verify the tree built.
    expect(find.text('Splash'), findsOneWidget);
  });
}

