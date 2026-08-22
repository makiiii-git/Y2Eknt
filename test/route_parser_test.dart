import 'package:flutter_test/flutter_test.dart';

import 'package:y2ekinet/route_parser.dart';

/// 2026-08-22 に Pixel 7 の Yahoo!乗換案内 (Y!乗換案内) 共有機能から
/// 実際に取得したテキスト（全角スペース・波ダッシュ含め原文どおり）。
const realSample = '東京⇒仙台\n'
    '2026年08月28日\n'
    '11:20 ⇒ 12:51\n'
    '------------------------------\n'
    '所要時間　1時間31分\n'
    '運賃[IC優先] 11,630円\n'
    '乗換　0回\n'
    '距離　351.8km\n'
    '------------------------------\n'
    '\n'
    '■東京\n'
    '↓ 11:20～12:51\n'
    '↓ ＪＲ新幹線はやぶさ19号(H5系/E5系)  新青森行\n'
    '↓ 21番線発 → 12番線着\n'
    '■仙台\n'
    '---\n'
    '(運賃内訳)\n'
    '東京～仙台　6,270円\n'
    '東京～仙台　5,360円 (特急料金)\n'
    '\n'
    '★PC・スマホでこの検索結果を見る\n'
    'https://yahoo.jp/XXXXXX\n'
    '\n'
    '[Yahoo!乗換案内]\n'
    '↓アプリのダウンロードはこちらから\n'
    'https://transit.yahoo.co.jp/smartphone/app/?referrer=app_share\n';

void main() {
  group('RouteParser 実機サンプル', () {
    test('出発駅・到着駅・日付・時刻を抽出できる', () {
      final result = RouteParser.parse(realSample);
      expect(result.isSuccess, isTrue, reason: result.error);

      final info = result.routeInfo!;
      expect(info.departureStation, '東京');
      expect(info.arrivalStation, '仙台');
      expect(info.year, 2026);
      expect(info.month, 8);
      expect(info.day, 28);
      expect(info.departureTime, '11:20');
      expect(info.arrivalTime, '12:51');
    });

    test('区間（列車名・区間時刻）を抽出できる', () {
      final info = RouteParser.parse(realSample).routeInfo!;
      expect(info.legs, hasLength(1));

      final leg = info.legs.first;
      expect(leg.fromStation, '東京');
      expect(leg.toStation, '仙台');
      expect(leg.departureTime, '11:20');
      expect(leg.arrivalTime, '12:51');
      expect(leg.trainName, contains('はやぶさ19号'));
    });

    test('フッターのURLや運賃内訳を区間として誤検出しない', () {
      final info = RouteParser.parse(realSample).routeInfo!;
      for (final leg in info.legs) {
        expect(leg.trainName ?? '', isNot(contains('http')));
        expect(leg.trainName ?? '', isNot(contains('ダウンロード')));
      }
    });
  });

  group('RouteParser 乗換ありの経路', () {
    const multiLeg = '大宮⇒盛岡\n'
        '2026年09月01日\n'
        '09:00 ⇒ 12:00\n'
        '------------------------------\n'
        '■大宮\n'
        '↓ 09:00～10:00\n'
        '↓ ＪＲ新幹線やまびこ51号　仙台行\n'
        '■仙台\n'
        '↓ 10:30～12:00\n'
        '↓ ＪＲ新幹線はやぶさ103号　新青森行\n'
        '■盛岡\n'
        '---\n';

    test('2区間を順に抽出できる', () {
      final result = RouteParser.parse(multiLeg);
      expect(result.isSuccess, isTrue, reason: result.error);

      final info = result.routeInfo!;
      expect(info.legs, hasLength(2));
      expect(info.legs[0].fromStation, '大宮');
      expect(info.legs[0].toStation, '仙台');
      expect(info.legs[0].trainName, contains('やまびこ51号'));
      expect(info.legs[1].fromStation, '仙台');
      expect(info.legs[1].toStation, '盛岡');
      expect(info.legs[1].departureTime, '10:30');
    });
  });

  group('RouteParser フォールバック', () {
    test('空テキストは失敗を返す', () {
      final result = RouteParser.parse('');
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('経路ヘッダーが無いテキストは失敗を返す', () {
      final result = RouteParser.parse('こんにちは\nこれは経路ではありません\n');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('出発駅'));
    });
  });
}
