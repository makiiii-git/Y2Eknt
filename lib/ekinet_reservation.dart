import 'dart:convert';

import 'route_history.dart';
import 'route_parser.dart';

/// えきねっとの申込フローのページから読み取った情報。
///
/// 2026-10-07 に実サイトで確認した構造:
/// - ページタイトルは「申込内容の確認｜JRきっぷ：えきねっと（JR東日本）」のように
///   「ページ名｜…」の形式。ページ見出しは `h2.pageHeadline`。
/// - 申込内容の確認ページでは乗車駅・時刻が `.qrShare_titleReslutStNameGeton`
///   （例「東京 18時20分 発」）、降車駅が `.qrShare_titleReslutStNameGetoff`、
///   日付を含む要約が `.qrShare_titleReslut`（例「2026年10月8日（木） 東京 18時20分 …」）。
/// - 列車名は「はやぶさ３７号」のように全角数字で表示される。
class EkinetPageSnapshot {
  const EkinetPageSnapshot({
    this.title = '',
    this.headline = '',
    this.geton = '',
    this.getoff = '',
    this.summary = '',
    this.train = '',
  });

  final String title;
  final String headline;
  final String geton;
  final String getoff;
  final String summary;
  final String train;

  factory EkinetPageSnapshot.fromJson(Map<String, dynamic> json) =>
      EkinetPageSnapshot(
        title: json['title'] as String? ?? '',
        headline: json['headline'] as String? ?? '',
        geton: json['geton'] as String? ?? '',
        getoff: json['getoff'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        train: json['train'] as String? ?? '',
      );

  /// `runJavaScriptReturningResult` の戻り値（JSON 文字列。Android では
  /// さらに文字列リテラルとして二重にエンコードされることがある）から生成する。
  static EkinetPageSnapshot? tryParse(String raw) {
    try {
      var s = raw;
      if (s.startsWith('"')) s = jsonDecode(s) as String;
      return EkinetPageSnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// ページ名（タイトルの「｜」より前）。
  String get pageName => title.split(RegExp(r'[｜|]')).first.trim();

  /// 申込の完了ページか。ページ名または見出しが「完了」を含み、
  /// かつ確認ページの注意書き「申込は完了していません」ではないこと。
  bool get isCompletionPage {
    for (final s in [pageName, headline]) {
      if (s.contains('完了') && !s.contains('していません') && !s.contains('確認')) {
        return true;
      }
    }
    return false;
  }

  static String _toHalfWidthDigits(String s) => s.replaceAllMapped(
      RegExp('[０-９]'), (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0));

  static final _stationTimeRe = RegExp(r'^(.+?)\s*(\d{1,2})時(\d{2})分');

  /// 乗車駅名（読み取れなければ null）。
  String? get departureStation =>
      _stationTimeRe.firstMatch(_toHalfWidthDigits(geton))?.group(1)?.trim();

  /// 乗車時刻 "HH:MM"（読み取れなければ null）。
  String? get departureTime {
    final m = _stationTimeRe.firstMatch(_toHalfWidthDigits(geton));
    if (m == null) return null;
    return '${m.group(2)!.padLeft(2, '0')}:${m.group(3)}';
  }

  /// 降車時刻 "HH:MM"（読み取れなければ null）。
  String? get arrivalTime {
    final m = _stationTimeRe.firstMatch(_toHalfWidthDigits(getoff));
    if (m == null) return null;
    return '${m.group(2)!.padLeft(2, '0')}:${m.group(3)}';
  }

  /// 乗車日（読み取れなければ null）。
  DateTime? get date {
    final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日')
        .firstMatch(_toHalfWidthDigits(summary));
    if (m == null) return null;
    return DateTime(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  /// 列車名（半角数字に正規化。例「はやぶさ37号」）。読み取れなければ null。
  String? get trainName => train.isEmpty ? null : _toHalfWidthDigits(train);
}

/// WebView を閉じたときの申込結果の判定。
class ReservationOutcome {
  const ReservationOutcome({
    required this.status,
    this.reservedTrain,
    this.reservedDepartureTime,
    this.itineraryVerified = false,
  });

  final ReservationStatus status;
  final String? reservedTrain;
  final String? reservedDepartureTime;

  /// 申込内容（列車の時刻）を読み取って共有経路と照合できたか。
  /// false のときは完了は検知したが列車の一致は確認できていない。
  final bool itineraryVerified;

  /// ユーザーに結果を見せて記録すべきか。検索もせずに閉じた場合は false。
  bool get shouldRecord => status != ReservationStatus.unknown;
}

/// えきねっとの申込フローを WebView の遷移から追跡し、閉じたときの結果を判定する。
///
/// 2026-10-07 に実サイトで確認したページ遷移（URL 末尾はコントローラ名）:
/// ```
/// RouteSearchConditionInput（検索条件）→ RouteList（経路検索結果）
/// → FacilityDiscountSelect（きっぷ・座席の種類選択）→ member/wb/Login（ログイン）
/// → SelectSeat（座席の指定）→ ApplicationContentConfirmation（申込内容の確認）
/// → 「この内容で確定」→ 申込の完了ページ
/// ```
/// 完了ページは実予約が必要なため URL 未確認。確認ページを通過したあとに
/// 見出しが「完了」を含むページ（または URL に Complet を含むページ）へ
/// 遷移したら完了とみなす。申し込んだ列車の時刻は確認ページから読み取り、
/// 共有経路の JR 区間の発時刻と照合して「共有どおり」か「別の列車」かを決める。
class EkinetReservationTracker {
  EkinetReservationTracker(this.routeInfo);

  final RouteInfo routeInfo;

  bool _searched = false;
  bool _confirmed = false;
  bool _completed = false;
  EkinetPageSnapshot? _itinerary;

  /// 検索条件ページから先（検索結果以降）へ進んだか。
  bool get progressed => _searched;

  /// 申込の完了ページを検知したか。
  bool get completed => _completed;

  static bool _isReserveFlow(String url) => url.contains('/reserve/wb/');
  static bool _isConditionPage(String url) =>
      url.contains('RouteSearchConditionInput');
  static bool _isConfirmationPage(String url) =>
      url.contains('ApplicationContentConfirmation');
  static final _completionUrlRe = RegExp(r'/reserve/wb/[A-Za-z]*Complet');

  /// URL の遷移（onUrlChange / onPageStarted）を通知する。
  void onUrl(String url) {
    if (_isReserveFlow(url) && !_isConditionPage(url)) _searched = true;
    if (_isConfirmationPage(url)) _confirmed = true;
    if (_confirmed && _completionUrlRe.hasMatch(url)) _completed = true;
  }

  /// ページ読み込み完了時に読み取った内容を通知する。
  void onSnapshot(String url, EkinetPageSnapshot snap) {
    onUrl(url);
    if (_isConfirmationPage(url) && snap.departureTime != null) {
      _itinerary = snap;
      return;
    }
    if (_confirmed && !_isConfirmationPage(url) && snap.isCompletionPage) {
      _completed = true;
      // 完了ページにも申込内容があれば、より確かなそちらを採用する
      if (snap.departureTime != null) _itinerary = snap;
    }
  }

  /// 現在までの遷移から申込結果を判定する。
  ReservationOutcome outcome() {
    if (!_searched) {
      return const ReservationOutcome(status: ReservationStatus.unknown);
    }
    if (!_completed) {
      return const ReservationOutcome(status: ReservationStatus.cancelled);
    }
    final it = _itinerary;
    final dep = it?.departureTime;
    if (it == null || dep == null) {
      return const ReservationOutcome(
          status: ReservationStatus.reserved, itineraryVerified: false);
    }
    final same = _sameTime(dep, routeInfo.jrSegment.departureTime) &&
        _sameDate(it.date, routeInfo);
    return ReservationOutcome(
      status: same
          ? ReservationStatus.reserved
          : ReservationStatus.reservedOtherTrain,
      reservedTrain: it.trainName,
      reservedDepartureTime: dep,
      itineraryVerified: true,
    );
  }

  /// "8:30" と "08:30" を同じ時刻として比較する。共有側が不明なら一致扱い。
  static bool _sameTime(String reserved, String? shared) {
    if (shared == null) return true;
    int toMin(String t) {
      final p = t.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    try {
      return toMin(reserved) == toMin(shared);
    } catch (_) {
      return false;
    }
  }

  /// どちらかの日付が不明なら一致扱い。
  static bool _sameDate(DateTime? reserved, RouteInfo info) {
    if (reserved == null || info.year == null) return true;
    return reserved.year == info.year &&
        reserved.month == info.month &&
        reserved.day == info.day;
  }
}
