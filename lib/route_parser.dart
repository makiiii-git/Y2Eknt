/// Yahoo!乗換案内の共有テキストを解析するパーサー。
///
/// 想定フォーマット（2026-08時点の実機サンプルより）:
/// ```
/// 東京⇒仙台
/// 2026年08月28日
/// 11:20 ⇒ 12:51
/// ------------------------------
/// 所要時間　1時間31分
/// 運賃[IC優先] 11,630円
/// ...
/// ■東京
/// ↓ 11:20～12:51
/// ↓ ＪＲ新幹線はやぶさ19号(H5系/E5系)  新青森行
/// ↓ 21番線発 → 12番線着
/// ■仙台
/// ---
/// ```
library;

/// 1区間（乗車列車）の情報。
class TrainLeg {
  const TrainLeg({
    required this.fromStation,
    required this.toStation,
    this.departureTime,
    this.arrivalTime,
    this.trainName,
  });

  final String fromStation;
  final String toStation;

  /// "11:20" 形式。
  final String? departureTime;
  final String? arrivalTime;

  /// 例: "ＪＲ新幹線はやぶさ19号(H5系/E5系)  新青森行"
  final String? trainName;

  /// JR管轄の区間か。Yahoo!乗換案内の共有テキストではJR路線・列車名に
  /// 「ＪＲ」（全角）が付くことを利用して判定する。
  bool get isJr =>
      trainName != null && RegExp(r'ＪＲ|JR').hasMatch(trainName!);
}

/// 経路のうち予約サービスへ渡す区間（乗車駅・降車駅・時刻）。
class RouteSegment {
  const RouteSegment({
    required this.fromStation,
    required this.toStation,
    this.departureTime,
    this.arrivalTime,
  });

  final String fromStation;
  final String toStation;
  final String? departureTime;
  final String? arrivalTime;
}

/// 経路全体の解析結果。
class RouteInfo {
  const RouteInfo({
    required this.departureStation,
    required this.arrivalStation,
    this.year,
    this.month,
    this.day,
    this.departureTime,
    this.arrivalTime,
    this.legs = const [],
  });

  final String departureStation;
  final String arrivalStation;
  final int? year;
  final int? month;
  final int? day;

  /// "11:20" 形式。
  final String? departureTime;
  final String? arrivalTime;
  final List<TrainLeg> legs;

  static final _tokaidoSanyoKyushuRe =
      RegExp(r'のぞみ|ひかり|こだま|みずほ|さくら|つばめ');

  /// 東海道・山陽・九州新幹線（EX予約の対象列車）を含む経路か。
  bool get usesTokaidoSanyoKyushu => legs.any(
      (l) => l.trainName != null && _tokaidoSanyoKyushuRe.hasMatch(l.trainName!));

  /// 予約サービスへ渡すJR区間。
  ///
  /// 優先順位:
  /// 1. 新幹線・特急の区間（予約対象の列車）。山手線などJR在来線の
  ///    アクセス区間もここでは除かれる
  /// 2. 無ければJRの区間（地下鉄・私鉄のアクセス区間を除く）
  /// 3. どちらも判別できなければ経路全体
  RouteSegment get jrSegment {
    var target = legs
        .where((l) =>
            l.trainName != null &&
            RegExp(r'新幹線|特急').hasMatch(l.trainName!))
        .toList();
    if (target.isEmpty) {
      target = legs.where((l) => l.isJr).toList();
    }
    if (target.isEmpty) {
      return RouteSegment(
        fromStation: departureStation,
        toStation: arrivalStation,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
      );
    }
    return RouteSegment(
      fromStation: target.first.fromStation,
      toStation: target.last.toStation,
      departureTime: target.first.departureTime ?? departureTime,
      arrivalTime: target.last.arrivalTime ?? arrivalTime,
    );
  }
}

/// パース結果。失敗時は [routeInfo] が null で [error] に理由が入る。
class ParseResult {
  const ParseResult.success(RouteInfo this.routeInfo) : error = null;
  const ParseResult.failure(String this.error) : routeInfo = null;

  final RouteInfo? routeInfo;
  final String? error;

  bool get isSuccess => routeInfo != null;
}

class RouteParser {
  /// 「東京⇒仙台」の行。
  static final _headerRe = RegExp(r'^(.+?)(?:⇒|→)(.+)$');

  /// 「2026年08月28日」。曜日付き「(金)」等が続いても許容する。
  static final _dateRe = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日');

  /// 「11:20 ⇒ 12:51」。
  static final _totalTimeRe =
      RegExp(r'^(\d{1,2}:\d{2})\s*(?:⇒|→)\s*(\d{1,2}:\d{2})$');

  /// 区間の時刻「↓ 11:20～12:51」。波ダッシュの揺れ（U+FF5E/U+301C/~）を許容。
  static final _legTimeRe =
      RegExp(r'(\d{1,2}:\d{2})\s*[～〜~]\s*(\d{1,2}:\d{2})');

  /// 「■東京」の駅行。
  static final _stationRe = RegExp(r'^■(.+)$');

  /// 同名駅を区別するためYahoo!乗換案内が付ける都道府県の接尾辞。
  /// 例: 「大宮（埼玉）」「府中（東京）」。えきねっとの駅名入力では
  /// この接尾辞があると駅を特定できないため取り除く。
  ///
  /// 「埼玉」「埼玉県」のように 都/道/府/県 の有無どちらの表記も許容する。
  /// 括弧内が47都道府県名のときだけ除去し、駅名そのものに含まれる
  /// 括弧（「新宿（西口）」のようなバス停表記など）は残す。
  static final _prefectureSuffixRe = RegExp(
    r'[（(](?:'
    '北海道|青森|岩手|宮城|秋田|山形|福島|'
    '茨城|栃木|群馬|埼玉|千葉|東京|神奈川|'
    '新潟|富山|石川|福井|山梨|長野|岐阜|静岡|愛知|三重|'
    '滋賀|京都|大阪|兵庫|奈良|和歌山|'
    '鳥取|島根|岡山|広島|山口|徳島|香川|愛媛|高知|'
    '福岡|佐賀|長崎|熊本|大分|宮崎|鹿児島|沖縄'
    r')[都道府県]?[）)]\s*$',
  );

  /// 駅名から都道府県の接尾辞を取り除く。
  static String normalizeStation(String name) =>
      name.replaceFirst(_prefectureSuffixRe, '').trim();

  /// フッター以降（URL・注記）を打ち切る行。
  static final _footerRe = RegExp(r'^(?:---$|★|\(運賃内訳\)|https?://)');

  static ParseResult parse(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return ParseResult.failure('テキストが空です');
    }

    String? depStation;
    String? arrStation;
    int? year, month, day;
    String? depTime, arrTime;

    // ヘッダー部（■ブロックより前）から出発・到着・日付・時刻を抽出する
    for (final line in lines) {
      if (_stationRe.hasMatch(line)) break;
      if (depStation == null) {
        final m = _headerRe.firstMatch(line);
        // 「東京⇒仙台」のみ対象（時刻行 11:20 ⇒ 12:51 と区別する）
        if (m != null && !line.contains(':')) {
          depStation = normalizeStation(m.group(1)!);
          arrStation = normalizeStation(m.group(2)!);
          continue;
        }
      }
      final d = _dateRe.firstMatch(line);
      if (d != null && year == null) {
        year = int.parse(d.group(1)!);
        month = int.parse(d.group(2)!);
        day = int.parse(d.group(3)!);
        continue;
      }
      final t = _totalTimeRe.firstMatch(line);
      if (t != null && depTime == null) {
        depTime = t.group(1);
        arrTime = t.group(2);
      }
    }

    if (depStation == null || arrStation == null) {
      return ParseResult.failure('出発駅・到着駅の行（例: 東京⇒仙台）が見つかりません');
    }

    // ■駅 〜 ■駅 のブロックから区間情報を抽出する
    final legs = <TrainLeg>[];
    String? currentStation;
    String? legDep, legArr, trainName;
    for (final line in lines) {
      if (_footerRe.hasMatch(line)) break;
      final s = _stationRe.firstMatch(line);
      if (s != null) {
        final station = normalizeStation(s.group(1)!);
        if (currentStation != null) {
          legs.add(TrainLeg(
            fromStation: currentStation,
            toStation: station,
            departureTime: legDep,
            arrivalTime: legArr,
            trainName: trainName,
          ));
        }
        currentStation = station;
        legDep = legArr = trainName = null;
        continue;
      }
      if (currentStation != null && line.startsWith('↓')) {
        final body = line.substring(1).trim();
        final t = _legTimeRe.firstMatch(body);
        if (t != null) {
          legDep = t.group(1);
          legArr = t.group(2);
        } else if (!body.contains('番線')) {
          // 時刻でも番線案内でもない↓行は列車名とみなす
          trainName ??= body;
        }
      }
    }

    return ParseResult.success(RouteInfo(
      departureStation: depStation,
      arrivalStation: arrStation,
      year: year,
      month: month,
      day: day,
      departureTime: depTime,
      arrivalTime: arrTime,
      legs: legs,
    ));
  }
}
