import 'package:flutter_test/flutter_test.dart';

import 'package:simple_card_v1_2/main.dart';

void main() {
  testWidgets('App root smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SimpleCardApp());
    await tester.pumpAndSettle();

    expect(find.byType(SimpleCardApp), findsOneWidget);
  });
}
