import 'dart:convert';

import 'route_history.dart';
import 'route_parser.dart';

/// えきねっとの申込フローのページから読み取った情報。
///
/// 2026-10-07 に実サイトで確認した構造:
/// - ページタイトルは「申込内容の確認｜JRきっぷ：えきねっと（JR東日本）」のように
///   「ページ名｜…」の形式。ページ見出しは `h2.pageHeadline`。
/// - 申込内容の確認ページには「検索した経路の要約」（`.qrShare_formTrain` 内、
///   例「2026年10月8日（木） 東京 18時20分 仙台 19時51分 …」）と、実際に申し込む
///   「列車ごとの乗降」（`.selService_formTrain` 内の `.qrShare_titleReslutStNameGeton`、
///   例「東京 18時20分 発」）がある。列車を変更した場合に正しいのは後者なので、
///   読み取りは後者を優先する。
/// - 列車名は `.icSeat_formTrainListNameW`（例「はやぶさ３７号東北・北海道新幹線」）。
///   全角数字で表示される。
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
    this.completionDetected = false,
  });

  final ReservationStatus status;
  final String? reservedTrain;
  final String? reservedDepartureTime;

  /// 申込内容（列車の時刻）を読み取って共有経路と照合できたか。
  /// false のときは確認画面には達したが列車の一致は確認できていない。
  final bool itineraryVerified;

  /// 申込の完了ページまで検知できたか。false のときは「申込内容の確認」まで
  /// 進んだことだけを根拠に、確定したものとみなしている。
  final bool completionDetected;

  /// ユーザーに結果を見せて記録すべきか。確認画面に達していなければ false。
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
/// 判定点は「申込内容の確認」ページ。この先は「この内容で確定」を押すだけ
/// （クレジットカード決済）なので、確認ページに達したら申し込んだものとみなし、
/// そこに表示された列車の発時刻・日付を共有経路の JR 区間と照合して
/// 「共有どおり」か「別の列車」かを決める。確認ページに達せずに閉じた場合は
/// 判定しない（検索や空席確認だけの利用を「中止」として記録しないため）。
///
/// 完了ページは実予約が必要なため URL 未確認。確認ページを通過したあとに
/// 見出しが「完了」を含むページ（または URL に Complet を含むページ）へ
/// 遷移したら完了を検知したものとして [ReservationOutcome.completionDetected]
/// に反映する（判定自体は変わらず、ポップアップの文言に使う）。
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
    if (!_confirmed) {
      return const ReservationOutcome(status: ReservationStatus.unknown);
    }
    final it = _itinerary;
    final dep = it?.departureTime;
    if (it == null || dep == null) {
      return ReservationOutcome(
        status: ReservationStatus.reserved,
        itineraryVerified: false,
        completionDetected: _completed,
      );
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
      completionDetected: _completed,
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
