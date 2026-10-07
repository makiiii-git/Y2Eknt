import 'package:flutter_test/flutter_test.dart';

import 'package:y2eknt/ekinet_reservation.dart';
import 'package:y2eknt/route_history.dart';
import 'package:y2eknt/route_parser.dart';

void main() {
  const info = RouteInfo(
    departureStation: '東京',
    arrivalStation: '仙台',
    year: 2026,
    month: 10,
    day: 8,
    departureTime: '18:20',
    arrivalTime: '19:51',
  );

  // 2026-10-07 に実機で確認した URL とページ内容
  const base = 'https://www.eki-net.com/Personal/reserve/wb/';
  const conditionUrl = '${base}RouteSearchConditionInput/Index';
  const routeListUrl = '${base}RouteList/Index';
  const confirmUrl = '${base}ApplicationContentConfirmation/Index';
  const completeUrl = '${base}ApplicationComplete/Index';

  const confirmSnap = EkinetPageSnapshot(
    title: '申込内容の確認｜JRきっぷ：えきねっと（JR東日本）',
    headline: '申込内容の確認',
    geton: '東京 18時20分 発',
    getoff: '仙台 19時51分 着',
    summary: '2026年10月8日（木） 東京 18時20分 仙台 19時51分（1時間31分） 乗換0回 351.8km おとな1人',
    train: 'はやぶさ３７号',
  );
  const completeSnap = EkinetPageSnapshot(
    title: '申込の完了｜JRきっぷ：えきねっと（JR東日本）',
    headline: '申込の完了',
  );

  group('EkinetPageSnapshot', () {
    test('確認ページから駅・時刻・日付・列車名を読み取る', () {
      expect(confirmSnap.departureStation, '東京');
      expect(confirmSnap.departureTime, '18:20');
      expect(confirmSnap.arrivalTime, '19:51');
      expect(confirmSnap.date, DateTime(2026, 10, 8));
      expect(confirmSnap.trainName, 'はやぶさ37号');
    });

    test('全角数字の時刻も読める', () {
      const s = EkinetPageSnapshot(geton: '東京 ８時０５分 発');
      expect(s.departureTime, '08:05');
    });

    test('確認ページ（「申込は完了していません」を含む）は完了ページではない', () {
      expect(confirmSnap.isCompletionPage, isFalse);
      const withNote = EkinetPageSnapshot(
        title: '申込内容の確認｜JRきっぷ',
        headline: '申込は完了していません。「この内容で確定」が押されなかった場合は自動キャンセルになります。',
      );
      expect(withNote.isCompletionPage, isFalse);
    });

    test('ページ名または見出しが「完了」なら完了ページ', () {
      expect(completeSnap.isCompletionPage, isTrue);
      expect(
          const EkinetPageSnapshot(title: '申込完了｜JRきっぷ').isCompletionPage,
          isTrue);
      expect(const EkinetPageSnapshot(headline: '申込完了').isCompletionPage,
          isTrue);
    });

    test('tryParse は二重にエンコードされた JSON も読む', () {
      const json = '{"title":"申込の完了｜JRきっぷ","headline":"申込の完了"}';
      expect(EkinetPageSnapshot.tryParse(json)?.isCompletionPage, isTrue);
      final doubly = '"${json.replaceAll('"', r'\"')}"';
      expect(EkinetPageSnapshot.tryParse(doubly)?.isCompletionPage, isTrue);
      expect(EkinetPageSnapshot.tryParse('not json'), isNull);
    });
  });

  group('EkinetReservationTracker', () {
    test('検索せずに閉じたら unknown で記録しない', () {
      final t = EkinetReservationTracker(info)..onUrl(conditionUrl);
      final o = t.outcome();
      expect(o.status, ReservationStatus.unknown);
      expect(o.shouldRecord, isFalse);
    });

    test('検索結果まで進んで閉じたら cancelled', () {
      final t = EkinetReservationTracker(info)
        ..onUrl(conditionUrl)
        ..onUrl(routeListUrl);
      final o = t.outcome();
      expect(o.status, ReservationStatus.cancelled);
      expect(o.shouldRecord, isTrue);
    });

    test('確認ページで閉じても cancelled（確定していない）', () {
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, confirmSnap);
      expect(t.outcome().status, ReservationStatus.cancelled);
    });

    test('確認→完了で共有どおりの時刻なら reserved', () {
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, confirmSnap)
        ..onSnapshot('${base}SomeUnknownPage/Index', completeSnap);
      final o = t.outcome();
      expect(o.status, ReservationStatus.reserved);
      expect(o.itineraryVerified, isTrue);
      expect(o.reservedTrain, 'はやぶさ37号');
      expect(o.reservedDepartureTime, '18:20');
    });

    test('確認→完了で時刻が違えば reservedOtherTrain', () {
      const other = EkinetPageSnapshot(
        title: '申込内容の確認｜JRきっぷ',
        headline: '申込内容の確認',
        geton: '東京 18時28分 発',
        getoff: '仙台 20時23分 着',
        summary: '2026年10月8日（木） 東京 18時28分 仙台 20時23分',
        train: 'やまびこ１５５号',
      );
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, other)
        ..onSnapshot(completeUrl, completeSnap);
      final o = t.outcome();
      expect(o.status, ReservationStatus.reservedOtherTrain);
      expect(o.reservedTrain, 'やまびこ155号');
      expect(o.reservedDepartureTime, '18:28');
    });

    test('時刻が同じでも日付が違えば reservedOtherTrain', () {
      const otherDay = EkinetPageSnapshot(
        title: '申込内容の確認｜JRきっぷ',
        headline: '申込内容の確認',
        geton: '東京 18時20分 発',
        summary: '2026年10月9日（金） 東京 18時20分 仙台 19時51分',
      );
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, otherDay)
        ..onSnapshot(completeUrl, completeSnap);
      expect(t.outcome().status, ReservationStatus.reservedOtherTrain);
    });

    test('"8:30" と "08:30" は同じ時刻として扱う', () {
      const i = RouteInfo(
          departureStation: '東京', arrivalStation: '仙台', departureTime: '8:30');
      const snap = EkinetPageSnapshot(
          title: '申込内容の確認｜JRきっぷ', geton: '東京 08時30分 発');
      final t = EkinetReservationTracker(i)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, snap)
        ..onSnapshot(completeUrl, completeSnap);
      expect(t.outcome().status, ReservationStatus.reserved);
    });

    test('確認ページを経ずに「完了」見出しが出ても完了扱いしない', () {
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot('${base}FacilityDiscountSelect/Index',
            const EkinetPageSnapshot(headline: '会員登録完了'));
      expect(t.outcome().status, ReservationStatus.cancelled);
    });

    test('確認後に URL が Complet を含めば見出しが読めなくても完了', () {
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, confirmSnap)
        ..onUrl(completeUrl);
      expect(t.outcome().status, ReservationStatus.reserved);
    });

    test('申込内容を読めなかった完了は reserved だが照合なし', () {
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onUrl(confirmUrl)
        ..onSnapshot(completeUrl, completeSnap);
      final o = t.outcome();
      expect(o.status, ReservationStatus.reserved);
      expect(o.itineraryVerified, isFalse);
      expect(o.reservedDepartureTime, isNull);
    });

    test('完了ページにも申込内容があればそちらを優先する', () {
      const completeWithItinerary = EkinetPageSnapshot(
        title: '申込の完了｜JRきっぷ',
        headline: '申込の完了',
        geton: '東京 18時28分 発',
        train: 'やまびこ１５５号',
      );
      final t = EkinetReservationTracker(info)
        ..onUrl(routeListUrl)
        ..onSnapshot(confirmUrl, confirmSnap)
        ..onSnapshot(completeUrl, completeWithItinerary);
      final o = t.outcome();
      expect(o.status, ReservationStatus.reservedOtherTrain);
      expect(o.reservedDepartureTime, '18:28');
    });
  });
}
