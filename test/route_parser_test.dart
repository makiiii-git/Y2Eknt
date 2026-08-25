import 'package:flutter_test/flutter_test.dart';

import 'package:y2eknt/route_parser.dart';

/// 2026-08-22 に Yahoo!乗換案内 (Y!乗換案内) の共有機能から実際に取得した
/// テキスト（全角スペース・波ダッシュ含め原文どおり。短縮URLのみダミー化）。
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

  group('RouteInfo.usesTokaidoSanyoKyushu', () {
    test('はやぶさ（東北新幹線）は false', () {
      final info = RouteParser.parse(realSample).routeInfo!;
      expect(info.usesTokaidoSanyoKyushu, isFalse);
    });

    test('のぞみ（東海道新幹線）は true', () {
      const tokaido = '東京⇒新大阪\n'
          '2026年09月01日\n'
          '09:00 ⇒ 11:30\n'
          '■東京\n'
          '↓ 09:00～11:30\n'
          '↓ ＪＲ新幹線のぞみ203号　新大阪行\n'
          '■新大阪\n'
          '---\n';
      final info = RouteParser.parse(tokaido).routeInfo!;
      expect(info.usesTokaidoSanyoKyushu, isTrue);
    });
  });

  group('RouteInfo.jrSegment', () {
    const withAccessLegs = '新宿⇒仙台\n'
        '2026年09月01日\n'
        '08:30 ⇒ 12:51\n'
        '------------------------------\n'
        '■新宿\n'
        '↓ 08:30～08:45\n'
        '↓ 東京メトロ丸ノ内線 池袋行\n'
        '■東京\n'
        '↓ 11:20～12:51\n'
        '↓ ＪＲ新幹線はやぶさ19号 新青森行\n'
        '■仙台\n'
        '↓ 13:00～13:10\n'
        '↓ 仙台市地下鉄南北線 泉中央行\n'
        '■泉中央\n'
        '---\n';

    test('地下鉄・私鉄のアクセス区間を除いたJR区間を返す', () {
      final result = RouteParser.parse(withAccessLegs.replaceFirst(
          '新宿⇒仙台', '新宿⇒泉中央'));
      final seg = result.routeInfo!.jrSegment;
      expect(seg.fromStation, '東京');
      expect(seg.toStation, '仙台');
      expect(seg.departureTime, '11:20');
      expect(seg.arrivalTime, '12:51');
    });

    test('JR在来線のアクセス区間も除き新幹線区間を優先する', () {
      // 実機データを基にした形式（駅名は差し替え済み）: 飯田橋→有楽町(メトロ)→東京(ＪＲ山手線)
      // →仙台(新幹線)→泉中央(地下鉄) の形
      const realWorld = '飯田橋⇒泉中央\n'
          '2026年08月28日\n'
          '13:40 ⇒ 16:00\n'
          '■飯田橋\n'
          '↓ 13:40～13:48\n'
          '↓ 東京メトロ有楽町線  保谷行\n'
          '■有楽町\n'
          '↓ 13:58～14:00\n'
          '↓ ＪＲ山手線内回り  東京・上野方面\n'
          '■東京\n'
          '↓ 14:20～15:51\n'
          '↓ ＪＲ新幹線はやぶさ25号 新青森行\n'
          '■仙台\n'
          '↓ 15:55～16:00\n'
          '↓ 仙台市地下鉄南北線 泉中央行\n'
          '■泉中央\n'
          '---\n';
      final seg = RouteParser.parse(realWorld).routeInfo!.jrSegment;
      expect(seg.fromStation, '東京');
      expect(seg.toStation, '仙台');
      expect(seg.departureTime, '14:20');
      expect(seg.arrivalTime, '15:51');
    });

    test('JR区間が無ければ経路全体を返す', () {
      const subwayOnly = '新宿⇒池袋\n'
          '2026年09月01日\n'
          '08:30 ⇒ 08:45\n'
          '■新宿\n'
          '↓ 08:30～08:45\n'
          '↓ 東京メトロ丸ノ内線 池袋行\n'
          '■池袋\n'
          '---\n';
      final seg = RouteParser.parse(subwayOnly).routeInfo!.jrSegment;
      expect(seg.fromStation, '新宿');
      expect(seg.toStation, '池袋');
      expect(seg.departureTime, '08:30');
    });

    test('全区間JRなら経路全体と一致する', () {
      final seg = RouteParser.parse(realSample).routeInfo!.jrSegment;
      expect(seg.fromStation, '東京');
      expect(seg.toStation, '仙台');
      expect(seg.departureTime, '11:20');
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

  group('RouteParser.normalizeStation 末尾の括弧書き', () {
    test('同名駅を区別する都道府県を取り除く', () {
      expect(RouteParser.normalizeStation('大宮（埼玉）'), '大宮');
      expect(RouteParser.normalizeStation('大宮(埼玉)'), '大宮');
      // Yahoo!乗換案内の実際の表記は半角括弧＋「県」付き（実機で確認）
      expect(RouteParser.normalizeStation('大宮(埼玉県)'), '大宮');
      expect(RouteParser.normalizeStation('府中(東京都)'), '府中');
      expect(RouteParser.normalizeStation('大川(北海道)'), '大川');
    });

    test('経路種別や路線・運航会社の補足も取り除く', () {
      expect(RouteParser.normalizeStation('羽田空港(空路)'), '羽田空港');
      expect(RouteParser.normalizeStation('羽田空港第１ターミナル（モノレール/JAL）'),
          '羽田空港第１ターミナル');
      expect(RouteParser.normalizeStation('東京(バス)'), '東京');
      expect(RouteParser.normalizeStation('新宿（西口）'), '新宿');
    });

    test('括弧書きが複数続く場合もすべて取り除く', () {
      expect(RouteParser.normalizeStation('羽田空港第２ターミナル（モノレール）（東京都）'),
          '羽田空港第２ターミナル');
    });

    test('括弧が無い駅名はそのまま', () {
      expect(RouteParser.normalizeStation('東京'), '東京');
      expect(RouteParser.normalizeStation('新大阪'), '新大阪');
    });

    test('括弧を外すと空になる場合は元の表記を残す', () {
      expect(RouteParser.normalizeStation('（不明）'), '（不明）');
    });

    test('前後の空白を取り除く', () {
      expect(RouteParser.normalizeStation('大宮 (埼玉県) '), '大宮');
    });
  });

  group('RouteParser 都道府県つき駅名の経路', () {
    const sample = '大宮(埼玉県)⇒金沢\n'
        '2026年10月03日\n'
        '08:30 ⇒ 10:32\n'
        '------------------------------\n'
        '乗換　0回\n'
        '------------------------------\n'
        '\n'
        '■大宮(埼玉県)\n'
        '↓ 08:30～10:32\n'
        '↓ ＪＲ新幹線かがやき505号  金沢行\n'
        '■金沢\n';

    test('出発駅・到着駅から接尾辞が取り除かれる', () {
      final info = RouteParser.parse(sample).routeInfo!;
      expect(info.departureStation, '大宮');
      expect(info.arrivalStation, '金沢');
    });

    test('区間の駅名からも接尾辞が取り除かれる', () {
      final info = RouteParser.parse(sample).routeInfo!;
      expect(info.legs.single.fromStation, '大宮');
      expect(info.legs.single.toStation, '金沢');
    });

    test('えきねっとへ渡すJR区間も接尾辞なし', () {
      final seg = RouteParser.parse(sample).routeInfo!.jrSegment;
      expect(seg.fromStation, '大宮');
      expect(seg.toStation, '金沢');
    });
  });
}
