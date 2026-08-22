import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ex_launcher.dart';
import 'route_parser.dart';

/// EX予約（Web版）を開き、ログイン後の検索フォームへ自動入力するWebView画面。
///
/// EX予約の列車検索はログイン後にしか表示されない。ログインはユーザー自身が
/// このWebView内で行う（認証情報はJR東海のページと直接やり取りされ、
/// アプリは関与しない）。Cookieが保持されるため2回目以降はログイン不要。
///
/// 検索フォームのフィールド構造は非公開のため、ページごとに構造
/// （フィールド名・IDのみ。入力値は収集しない）をデバッグログに出力し、
/// 判明した構造に基づいて自動入力を実装する。
class ExWebViewPage extends StatefulWidget {
  const ExWebViewPage({super.key, required this.routeInfo});

  final RouteInfo routeInfo;

  @override
  State<ExWebViewPage> createState() => _ExWebViewPageState();
}

class _ExWebViewPageState extends State<ExWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: _onPageFinished,
      ))
      ..loadRequest(Uri.parse('https://expy.jp/login/'));
  }

  Future<void> _onPageFinished(String url) async {
    await _dumpFormStructure(url);
    await _tryAutofill(url);
  }

  /// フォーム構造（フィールド名・ID・selectの選択肢）をログに出力する。
  /// 自動入力の対応ページを増やすための開発用。ユーザーの入力値は収集しない。
  /// logcatの行長制限を避けるため分割して出力する。
  Future<void> _dumpFormStructure(String url) async {
    if (!kDebugMode) return;
    try {
      final result = await _controller.runJavaScriptReturningResult('''
JSON.stringify({
  url: location.href,
  title: document.title,
  fields: Array.from(document.querySelectorAll('input, select'))
    .filter(function(e) { return e.type !== 'hidden' || e.id; })
    .slice(0, 40)
    .map(function(e) {
      var f = e.tagName + ':' + (e.type || '') + ':' + (e.name || '') + ':' + (e.id || '');
      if (e.tagName === 'SELECT') {
        var opts = Array.from(e.options).slice(0, 45).map(function(o) {
          return o.value + '=' + o.text.trim().slice(0, 12);
        });
        f += ' OPTS[' + opts.join(',') + ']';
      }
      return f;
    })
})
''');
      final text = result.toString();
      debugPrint('EX_FORM_DUMP_BEGIN');
      for (var i = 0; i < text.length; i += 600) {
        final end = (i + 600 < text.length) ? i + 600 : text.length;
        debugPrint('EXD|${text.substring(i, end)}');
      }
      debugPrint('EX_FORM_DUMP_END');
    } catch (_) {
      // ダンプ失敗は無視（本機能に影響なし）
    }
  }

  /// ログイン後の検索条件設定ページで自動入力を試みる。
  ///
  /// フィールド構造は2026-08-23に実ページで確認したもの:
  /// 乗車駅=select[name=s6], 降車駅=select[name=s7]（駅名テキスト照合）,
  /// 時=select[name=02](06-23), 分=select[name=03](5分刻み),
  /// 出発/到着=select[name=04](1/2), 日付=hidden#hd_cal_val（形式は実行時判定）。
  /// フィールドが無いページでは何もしない（安全側）。
  Future<void> _tryAutofill(String url) async {
    if (_filled || !url.contains('/RSV_P/')) return;
    final info = widget.routeInfo;
    final seg = info.jrSegment;
    final dep = _js(seg.fromStation);
    final arr = _js(seg.toStation);
    final time = seg.departureTime?.split(':');
    final hh = time != null ? time[0].padLeft(2, '0') : '';
    final mm = time != null
        ? (int.parse(time[1]) ~/ 5 * 5).toString().padLeft(2, '0')
        : '';
    final hasDate = info.year != null && info.month != null && info.day != null;
    final ymd8 = hasDate
        ? '${info.year}${info.month!.toString().padLeft(2, '0')}'
            '${info.day!.toString().padLeft(2, '0')}'
        : '';
    // date_click() の第2引数（画面表示用テキスト）: 例 "2026年8月30日（日）"
    final dateDisp = hasDate
        ? () {
            const youbi = ['月', '火', '水', '木', '金', '土', '日'];
            final w = DateTime(info.year!, info.month!, info.day!).weekday;
            return '${info.year}年${info.month}月${info.day}日（${youbi[w - 1]}）';
          }()
        : '';

    try {
      final result = await _controller.runJavaScriptReturningResult('''
(function() {
  var s6 = document.getElementsByName('s6')[0];
  var s7 = document.getElementsByName('s7')[0];
  if (!s6 || !s7) return 'skip';
  function norm(t) { return t.replace(/[\\s\\u3000]/g, ''); }
  function fire(el) {
    el.dispatchEvent(new Event('input', {bubbles: true}));
    el.dispatchEvent(new Event('change', {bubbles: true}));
  }
  function selByText(sel, name) {
    for (var i = 0; i < sel.options.length; i++) {
      if (norm(sel.options[i].text) === name) {
        sel.selectedIndex = i;
        fire(sel);
        return true;
      }
    }
    return false;
  }
  function selByValue(name, v) {
    var el = document.getElementsByName(name)[0];
    if (!el || !v) return false;
    el.value = v;
    fire(el);
    return true;
  }
  var okDep = selByText(s6, '$dep');
  var okArr = selByText(s7, '$arr');
  if (!okDep || !okArr) return 'station-missing';
  selByValue('02', '$hh');
  selByValue('03', '$mm');
  selByValue('04', '1');
  // 日付: サイト公式の date_click() を使い、hidden値と画面表示を同時に更新する。
  // カレンダーの日付セル（class=YYYYMMDD selectable）をクリックするのが最も確実。
  var calSet = false;
  if ('$ymd8' !== '') {
    var cells = document.getElementsByClassName('$ymd8');
    var cell = null;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].className.indexOf('selectable') !== -1) { cell = cells[i]; break; }
    }
    if (cell) {
      cell.click();
      calSet = true;
    } else if (typeof date_click === 'function') {
      date_click('$ymd8', '$dateDisp');
      calSet = true;
    }
  }
  return calSet ? 'filled+cal' : 'filled';
})()
''');
      final r = result.toString();
      if (!r.contains('filled') || !mounted) return;
      _filled = true;
      final msg = r.contains('+cal')
          ? '検索条件を自動入力しました。内容を確認して「OK 予約を続ける」を押してください'
          : '駅と時刻を自動入力しました。日付は手動で選択してください';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 6),
      ));
    } catch (_) {
      // 対応外ページでは何もしない
    }
  }

  static String _js(String s) => s
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n');

  Future<void> _copySummary() async {
    await Clipboard.setData(
        ClipboardData(text: ExLauncher.buildSummary(widget.routeInfo)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('経路情報をコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EX予約'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '経路情報をコピー',
            onPressed: _copySummary,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'app') ExLauncher.launch(widget.routeInfo);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'app', child: Text('EXアプリで開く')),
            ],
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
