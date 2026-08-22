import 'route_parser.dart';

/// えきねっとの検索条件入力ページへの自動入力を組み立てる。
///
/// えきねっとには外部公開の条件付き遷移URL（GETパラメータ）が存在しないため
/// （2026-08 実サイト調査済み。検索フォームは POST + CSRF トークン方式）、
/// アプリ内 WebView で検索ページを開き、JavaScript でフォームへ入力する。
/// フィールド名は 2026-08-22 に実サイトで確認したもの。
class Ekinet {
  /// 新幹線・特急の検索条件入力ページ。
  static const String searchPageUrl =
      'https://www.eki-net.com/Personal/reserve/wb/RouteSearchConditionInput/Index';

  /// JS文字列リテラル用のエスケープ。
  static String _js(String s) => s
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n');

  /// [info] の内容を検索フォームへ入力するJavaScriptを生成する。
  ///
  /// 分は選択肢に確実に存在するよう5分単位に切り捨てる。
  /// 検索ボタンは押さず、内容の確認と実行はユーザーに委ねる。
  static String buildAutofillScript(RouteInfo info) {
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
  setVal('form_station_geton', '${_js(info.departureStation)}');
  setVal('form_station_getoff', '${_js(info.arrivalStation)}');
''');

    if (info.year != null && info.month != null && info.day != null) {
      final ymd = '${info.year!.toString().padLeft(4, '0')}'
          '${info.month!.toString().padLeft(2, '0')}'
          '${info.day!.toString().padLeft(2, '0')}';
      buf.write("  setSel('form_date_oneway_date', '$ymd');\n");
    }

    final dep = info.departureTime;
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
