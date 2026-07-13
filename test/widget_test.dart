import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/main.dart';

void main() {
  testWidgets('RoostApp smoke test — renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const RoostApp());

    // Verify the app bar title renders
    expect(find.text('Roost'), findsOneWidget);
  });
}
