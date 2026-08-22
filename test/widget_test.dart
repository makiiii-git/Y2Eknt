import 'package:flutter_test/flutter_test.dart';

import 'package:y2eknt/main.dart';

void main() {
  testWidgets('起動時に共有待ちの案内が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const Y2EkntApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('共有'), findsOneWidget);
  });
}
