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

  /// フォーム構造（フィールド名・IDのみ）をログに出力する。
  /// 自動入力の対応ページを増やすための開発用。値は一切収集しない。
  Future<void> _dumpFormStructure(String url) async {
    if (!kDebugMode) return;
    try {
      final result = await _controller.runJavaScriptReturningResult('''
JSON.stringify({
  url: location.href,
  title: document.title,
  fields: Array.from(document.querySelectorAll('input, select')).slice(0, 60)
    .map(function(e) {
      return e.tagName + ':' + (e.type || '') + ':' + (e.name || '') + ':' + (e.id || '');
    })
})
''');
      debugPrint('EX_FORM_DUMP_BEGIN');
      debugPrint(result.toString());
      debugPrint('EX_FORM_DUMP_END');
    } catch (_) {
      // ダンプ失敗は無視（本機能に影響なし）
    }
  }

  /// ログイン後の検索フォームと思われるページで自動入力を試みる。
  ///
  /// フィールド名は実ページの構造判明後に拡充する。存在しない場合は
  /// 何もしない（安全側）。
  Future<void> _tryAutofill(String url) async {
    if (_filled) return;
    final seg = widget.routeInfo.jrSegment;
    final dep = _js(seg.fromStation);
    final arr = _js(seg.toStation);
    final time = seg.departureTime?.split(':');
    final hour = time != null ? int.parse(time[0]).toString() : '';
    final minute = time != null ? (int.parse(time[1]) ~/ 10 * 10).toString() : '';
    final info = widget.routeInfo;
    final month = info.month?.toString() ?? '';
    final day = info.day?.toString() ?? '';

    try {
      final result = await _controller.runJavaScriptReturningResult('''
(function() {
  // 出発駅・到着駅の候補フィールドを名前のパターンで探す（EX予約の検索フォーム想定）
  function findField(patterns) {
    var els = document.querySelectorAll('input[type=text], select');
    for (var i = 0; i < els.length; i++) {
      var key = (els[i].name || '') + ' ' + (els[i].id || '');
      for (var j = 0; j < patterns.length; j++) {
        if (key.indexOf(patterns[j]) !== -1) return els[i];
      }
    }
    return null;
  }
  function setField(el, v) {
    if (!el || !v) return false;
    el.value = v;
    el.dispatchEvent(new Event('input', {bubbles: true}));
    el.dispatchEvent(new Event('change', {bubbles: true}));
    return true;
  }
  var dep = findField(['dep', 'Dep', 'ride', 'jyosha', 'fromSt']);
  var arr = findField(['arr', 'Arr', 'getoff', 'gesha', 'toSt']);
  var ok = false;
  if (dep && arr) {
    ok = setField(dep, '$dep') && setField(arr, '$arr');
    setField(findField(['month', 'Month', 'tuki']), '$month');
    setField(findField(['day', 'Day', 'hi']), '$day');
    setField(findField(['hour', 'Hour', 'ji']), '$hour');
    setField(findField(['min', 'Min', 'fun']), '$minute');
  }
  return ok ? 'filled' : 'skip';
})()
''');
      if (result.toString().contains('filled') && mounted) {
        _filled = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('検索条件を自動入力しました。内容を確認してください'),
          duration: Duration(seconds: 5),
        ));
      }
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
