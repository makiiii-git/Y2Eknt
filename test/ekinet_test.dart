import 'package:flutter_test/flutter_test.dart';

import 'package:y2eknt/ekinet.dart';
import 'package:y2eknt/route_parser.dart';

void main() {
  group('Ekinet.buildAutofillScript', () {
    const info = RouteInfo(
      departureStation: '東京',
      arrivalStation: '仙台',
      year: 2026,
      month: 8,
      day: 28,
      departureTime: '11:20',
      arrivalTime: '12:51',
    );

    test('駅名・日付・時刻がスクリプトに含まれる', () {
      final script = Ekinet.buildAutofillScript(info);
      expect(script, contains("setVal('form_station_geton', '東京')"));
      expect(script, contains("setVal('form_station_getoff', '仙台')"));
      expect(script, contains("setSel('form_date_oneway_date', '20260828')"));
      expect(script, contains("setSel('form_date_oneway_hour', '11')"));
      expect(script, contains("setSel('form_date_oneway_minute', '20')"));
    });

    test('分は5分単位に切り捨てる', () {
      const i = RouteInfo(
        departureStation: '東京',
        arrivalStation: '仙台',
        departureTime: '09:43',
      );
      final script = Ekinet.buildAutofillScript(i);
      expect(script, contains("setSel('form_date_oneway_minute', '40')"));
      expect(script, contains("setSel('form_date_oneway_hour', '9')"));
    });

    test('日付・時刻が無ければ駅名のみ入力する', () {
      const i = RouteInfo(departureStation: '東京', arrivalStation: '仙台');
      final script = Ekinet.buildAutofillScript(i);
      expect(script, contains('form_station_geton'));
      expect(script, isNot(contains('form_date_oneway_date')));
      expect(script, isNot(contains('form_date_oneway_hour')));
    });

    test('シングルクォートを含む駅名をエスケープする', () {
      const i = RouteInfo(departureStation: "O'Hare", arrivalStation: '仙台');
      final script = Ekinet.buildAutofillScript(i);
      expect(script, contains(r"O\'Hare"));
    });

    test('アクセス区間を除いたJR区間の駅・時刻を入力する', () {
      const i = RouteInfo(
        departureStation: '新宿',
        arrivalStation: '仙台',
        year: 2026,
        month: 9,
        day: 1,
        departureTime: '08:30',
        legs: [
          TrainLeg(
              fromStation: '新宿',
              toStation: '東京',
              departureTime: '08:30',
              arrivalTime: '08:45',
              trainName: '東京メトロ丸ノ内線 池袋行'),
          TrainLeg(
              fromStation: '東京',
              toStation: '仙台',
              departureTime: '11:20',
              arrivalTime: '12:51',
              trainName: 'ＪＲ新幹線はやぶさ19号 新青森行'),
        ],
      );
      final script = Ekinet.buildAutofillScript(i);
      expect(script, contains("setVal('form_station_geton', '東京')"));
      expect(script, contains("setVal('form_station_getoff', '仙台')"));
      expect(script, contains("setSel('form_date_oneway_hour', '11')"));
      expect(script, contains("setSel('form_date_oneway_minute', '20')"));
      expect(script, isNot(contains('新宿')));
    });
  });

  group('Ekinet.isSearchPage', () {
    test('検索条件入力ページのURLを判定する', () {
      expect(Ekinet.isSearchPage(Ekinet.searchPageUrl), isTrue);
      expect(
          Ekinet.isSearchPage(
              'https://www.eki-net.com/Personal/reserve/wb/RouteSearchConditionInput/SearchTrain'),
          isTrue);
      expect(Ekinet.isSearchPage('https://www.eki-net.com/Personal/Login'),
          isFalse);
    });
  });

  group('Ekinet.formReadyScript', () {
    test('自動入力で使う全フィールドの存在を確認する', () {
      for (final id in ['form_station_geton', 'form_station_getoff']) {
        expect(Ekinet.formReadyScript, contains("getElementById('$id')"));
      }
      for (final name in [
        'form_date_oneway_date',
        'form_date_oneway_hour',
        'form_date_oneway_minute',
      ]) {
        expect(Ekinet.formReadyScript, contains("getElementsByName('$name')"));
      }
    });
  });
}
