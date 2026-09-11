import 'route_parser.dart';

/// えきねっとの検索条件入力ページへの自動入力を組み立てる。
///
/// えきねっとには外部公開の条件付き遷移URL（GETパラメータ）が存在しないため
/// （2026-08 実サイト調査済み。検索フォームは POST + CSRF トークン方式）、
/// アプリ内 WebView で検索ページを開き、JavaScript でフォームへ入力する。
/// フィールド名は 2026-08-22 に実サイトで確認したもの。
///
/// 2026-09 以降、えきねっとは計測タグ（WalkMe・各種広告ピクセル）を多数読み込む
/// ようになり、load 完了まで 10 秒以上かかる一方、検索フォーム自体は静的 HTML で
/// DOM 構築直後（1〜2 秒）に存在する。ページ側の onload 処理はフォーム値を
/// 書き換えないため、load を待たずフォームの出現を検知して自動入力する。
class Ekinet {
  /// 新幹線・特急の検索条件入力ページ。
  static const String searchPageUrl =
      'https://www.eki-net.com/Personal/reserve/wb/RouteSearchConditionInput/Index';

  /// 検索条件入力ページかどうか（URL で判定）。
  static bool isSearchPage(String url) =>
      url.contains('RouteSearchConditionInput');

  /// 自動入力対象のフォーム要素がすべて存在するかを返す JavaScript 式。
  /// `runJavaScriptReturningResult` の結果が `true` なら入力可能。
  static const String formReadyScript = '(function() {'
      " return !!(document.getElementById('form_station_geton')"
      " && document.getElementById('form_station_getoff')"
      " && document.getElementsByName('form_date_oneway_date').length"
      " && document.getElementsByName('form_date_oneway_hour').length"
      " && document.getElementsByName('form_date_oneway_minute').length);"
      '})()';

  /// JS文字列リテラル用のエスケープ。
  static String _js(String s) => s
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n');

  /// [info] の内容を検索フォームへ入力するJavaScriptを生成する。
  ///
  /// 駅と時刻は地下鉄・私鉄などのアクセス区間を除いたJR区間
  /// （[RouteInfo.jrSegment]）を使う。
  /// 分は選択肢に確実に存在するよう5分単位に切り捨てる。
  /// 検索ボタンは押さず、内容の確認と実行はユーザーに委ねる。
  static String buildAutofillScript(RouteInfo info) {
    final seg = info.jrSegment;
    final buf = StringBuffer();
    buf.write('''
(function() {
  function setVal(id, v) {
    var e = document.getElementById(id);
    if (!e) return;
    e.value = v;
    e.dispatchEvent(new Event('input', {bubbles: true}));
    e.dispatchEvent(new Event('change', {bubbles: true}));
  }
  function setSel(name, v) {
    var es = document.getElementsByName(name);
    if (!es.length) return;
    es[0].value = v;
    es[0].dispatchEvent(new Event('change', {bubbles: true}));
  }
  setVal('form_station_geton', '${_js(seg.fromStation)}');
  setVal('form_station_getoff', '${_js(seg.toStation)}');
''');

    if (info.year != null && info.month != null && info.day != null) {
      final ymd = '${info.year!.toString().padLeft(4, '0')}'
          '${info.month!.toString().padLeft(2, '0')}'
          '${info.day!.toString().padLeft(2, '0')}';
      buf.write("  setSel('form_date_oneway_date', '$ymd');\n");
    }

    final dep = seg.departureTime;
    if (dep != null) {
      final parts = dep.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]) ~/ 5 * 5;
      buf.write("  setSel('form_date_oneway_hour', '$hour');\n");
      buf.write("  setSel('form_date_oneway_minute', '$minute');\n");
      // 「出発」時刻指定を選択する
      buf.write('''
  var depRadio = document.getElementById('form_date_oneway_Dep');
  if (depRadio) {
    depRadio.checked = true;
    depRadio.dispatchEvent(new Event('change', {bubbles: true}));
  }
''');
    }

    buf.write('})();\n');
    return buf.toString();
  }
}
