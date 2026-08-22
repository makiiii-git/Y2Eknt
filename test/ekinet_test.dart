import 'package:flutter_test/flutter_test.dart';

import 'package:y2ekinet/ekinet.dart';
import 'package:y2ekinet/route_parser.dart';

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
  });
}
