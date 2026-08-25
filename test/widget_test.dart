import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:y2eknt/build_config.dart';
import 'package:y2eknt/premium.dart';

import 'package:y2eknt/ad_banner.dart';
import 'package:y2eknt/main.dart';

void main() {
  testWidgets('起動時に共有待ちの案内が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const Y2EkntApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('共有'), findsOneWidget);
  });

  testWidgets('GitHub版はバナー広告を表示しない', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PremiumManager.instance.init();
    await tester.pumpWidget(const Y2EkntApp());
    await tester.pumpAndSettle();

    expect(find.byType(AdBanner), findsNothing);
  });

  test('GitHub版（PLAY_STOREフラグなし）は課金・広告を持たない', () {
    // このテストはフラグなしで実行されるためGitHub版の構成になる。
    // Play版でのみ広告とアプリ内課金を有効にする方針を固定する。
    expect(kIsPlayStoreBuild, isFalse,
        reason: 'テストはPLAY_STOREフラグなしで実行される想定');
  });

  testWidgets('GitHub版はプレミアム機能が最初から解放される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PremiumManager.instance.init();
    expect(PremiumManager.instance.isPremium.value, isTrue,
        reason: 'GitHub版はPlay Billingが使えず購入できないため');
  });
}
