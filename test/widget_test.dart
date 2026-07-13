import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/main.dart';

void main() {
  testWidgets('MyApp smoke test — renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the app bar title renders
    expect(find.text('Roost'), findsOneWidget);
  });
}
