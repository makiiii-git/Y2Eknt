import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:y2eknt/route_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteHistory', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('追加した履歴を新しい順に取得できる', () async {
      await RouteHistory.add('経路A', receivedAt: DateTime(2026, 8, 23, 9));
      await RouteHistory.add('経路B', receivedAt: DateTime(2026, 8, 23, 10));
      final list = await RouteHistory.load();
      expect(list.map((e) => e.text), ['経路B', '経路A']);
      expect(list[1].receivedAt, DateTime(2026, 8, 23, 9));
    });

    test('同じテキストは重複せず先頭に移動する', () async {
      await RouteHistory.add('経路A');
      await RouteHistory.add('経路B');
      await RouteHistory.add('経路A');
      final list = await RouteHistory.load();
      expect(list.map((e) => e.text), ['経路A', '経路B']);
    });

    test('上限を超えると古いものから削除される', () async {
      for (var i = 0; i < RouteHistory.maxEntries + 5; i++) {
        await RouteHistory.add('経路$i');
      }
      final list = await RouteHistory.load();
      expect(list.length, RouteHistory.maxEntries);
      expect(list.first.text, '経路${RouteHistory.maxEntries + 4}');
      expect(list.last.text, '経路5');
    });

    test('削除できる', () async {
      await RouteHistory.add('経路A');
      await RouteHistory.add('経路B');
      final list = await RouteHistory.load();
      await RouteHistory.remove(list[1]); // 経路A
      final after = await RouteHistory.load();
      expect(after.map((e) => e.text), ['経路B']);
    });

    test('壊れたデータは空扱い', () async {
      SharedPreferences.setMockInitialValues({'route_history': '{invalid'});
      expect(await RouteHistory.load(), isEmpty);
    });
  });
}
