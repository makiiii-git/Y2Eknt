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

    test('申込結果を記録して読み戻せる', () async {
      await RouteHistory.add('経路A');
      await RouteHistory.updateStatus(
        '経路A',
        ReservationStatus.reservedOtherTrain,
        reservedTrain: 'やまびこ155号',
        reservedDepartureTime: '18:28',
      );
      final e = (await RouteHistory.load()).single;
      expect(e.status, ReservationStatus.reservedOtherTrain);
      expect(e.status.isReserved, isTrue);
      expect(e.reservedTrain, 'やまびこ155号');
      expect(e.reservedDepartureTime, '18:28');
      expect((await RouteHistory.find('経路A'))?.status,
          ReservationStatus.reservedOtherTrain);
      expect(await RouteHistory.find('経路X'), isNull);
    });

    test('予約中止に更新すると列車情報は残らない', () async {
      await RouteHistory.add('経路A');
      await RouteHistory.updateStatus('経路A', ReservationStatus.cancelled,
          reservedTrain: 'はやぶさ37号', reservedDepartureTime: '18:20');
      final e = (await RouteHistory.load()).single;
      expect(e.status, ReservationStatus.cancelled);
      expect(e.status.isReserved, isFalse);
      expect(e.reservedTrain, isNull);
      expect(e.reservedDepartureTime, isNull);
    });

    test('同じテキストを再共有すると申込結果は未判定に戻る', () async {
      await RouteHistory.add('経路A');
      await RouteHistory.updateStatus('経路A', ReservationStatus.reserved);
      await RouteHistory.add('経路A');
      final e = (await RouteHistory.load()).single;
      expect(e.status, ReservationStatus.unknown);
    });

    test('履歴に無いテキストの更新は何もしない', () async {
      await RouteHistory.add('経路A');
      await RouteHistory.updateStatus('経路B', ReservationStatus.reserved);
      final list = await RouteHistory.load();
      expect(list.map((e) => e.text), ['経路A']);
      expect(list.single.status, ReservationStatus.unknown);
    });

    test('申込結果の無い旧形式データは未判定として読む', () async {
      SharedPreferences.setMockInitialValues({
        'route_history':
            '[{"text":"経路A","receivedAt":"2026-08-23T09:00:00.000"}]'
      });
      final e = (await RouteHistory.load()).single;
      expect(e.status, ReservationStatus.unknown);
      expect(e.reservedTrain, isNull);
    });

    test('未知の status 値は未判定として読む', () async {
      SharedPreferences.setMockInitialValues({
        'route_history':
            '[{"text":"経路A","receivedAt":"2026-08-23T09:00:00.000","status":"future"}]'
      });
      expect((await RouteHistory.load()).single.status,
          ReservationStatus.unknown);
    });
  });
}
