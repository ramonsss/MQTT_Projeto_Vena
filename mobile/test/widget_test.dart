import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vena_app/app.dart';

void main() {
  testWidgets('VenaApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VenaApp()));
    await tester.pump(); // one frame — avoids pumpAndSettle timeout from live streams
    // App built without throwing — no further assertion needed for a smoke check.
  });
}

