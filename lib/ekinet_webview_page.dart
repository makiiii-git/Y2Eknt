import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ekinet.dart';
import 'ekinet_reservation.dart';
import 'route_parser.dart';

/// えきねっとの検索ページを開き、経路情報を自動入力するWebView画面。
///
/// 閉じるときに、申込フローの画面遷移から判定した [ReservationOutcome] を
/// `Navigator.pop` の結果として返す（検索せずに閉じた場合は unknown）。
class EkinetWebViewPage extends StatefulWidget {
  const EkinetWebViewPage({super.key, required this.routeInfo});

  final RouteInfo routeInfo;

  @override
  State<EkinetWebViewPage> createState() => _EkinetWebViewPageState();
}

class _EkinetWebViewPageState extends State<EkinetWebViewPage> {
  /// フォーム出現を待つポーリングの間隔と上限。
  /// 上限を過ぎても [NavigationDelegate.onPageFinished] で最終的に入力する。
  static const _pollInterval = Duration(milliseconds: 200);
  static const _pollTimeout = Duration(seconds: 30);

  late final WebViewController _controller;
  late final EkinetReservationTracker _tracker;
  bool _filled = false;
  int _progress = 0;

  /// ページ遷移のたびに増やし、古いポーリングを止めるための世代番号。
  int _pollGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tracker = EkinetReservationTracker(widget.routeInfo);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        // えきねっとは計測タグの読み込みで load 完了が遅い（10秒超）ため、
        // load を待たずフォームが出現した時点で入力する
        onPageStarted: (url) {
          _tracker.onUrl(url);
          _pollFormAndFill(url);
        },
        onPageFinished: (url) {
          _autofillIfSearchPage(url);
          _captureSnapshot(url);
          _debugDumpPage(url);
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url == null) return;
          _tracker.onUrl(url);
          if (kDebugMode) debugPrint('EKINET_URL $url');
        },
      ))
      ..loadRequest(Uri.parse(Ekinet.searchPageUrl));
  }

  @override
  void dispose() {
    _pollGeneration++;
    super.dispose();
  }

  /// 検索条件入力ページの読み込み開始後、フォーム要素が揃うまで
  /// 短い間隔で確認し、揃い次第自動入力する。
  Future<void> _pollFormAndFill(String url) async {
    if (_filled || !Ekinet.isSearchPage(url)) return;
    final generation = ++_pollGeneration;
    final deadline = DateTime.now().add(_pollTimeout);
    while (mounted &&
        !_filled &&
        generation == _pollGeneration &&
        DateTime.now().isBefore(deadline)) {
      if (await _isFormReady()) {
        await _autofillIfSearchPage(url);
        return;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  /// 申込結果の判定に使う情報（ページ名・見出し・申込内容の駅と時刻）を
  /// ページから読み取ってトラッカーへ渡す。
  Future<void> _captureSnapshot(String url) async {
    if (!url.contains('eki-net.com')) return;
    try {
      final result =
          await _controller.runJavaScriptReturningResult(EkinetPageScript.snapshot);
      final snap = EkinetPageSnapshot.tryParse(result.toString());
      if (snap != null) _tracker.onSnapshot(url, snap);
    } catch (_) {
      // 読み取れないページ（エラー画面など）は判定材料にしない
    }
  }

  /// 【デバッグ版のみ】予約フローの各ページの構造を logcat に出力する。
  /// 予約完了の自動判定に使う URL・見出し・時刻表示の位置を調べるためのもので、
  /// 個人情報（氏名・予約番号・決済情報）は出力しない。
  Future<void> _debugDumpPage(String url) async {
    if (!kDebugMode) return;
    try {
      final result = await _controller.runJavaScriptReturningResult(r'''
(function() {
  function txt(e) { return (e.textContent || '').replace(/\s+/g, ' ').trim(); }
  var heads = Array.prototype.slice.call(
      document.querySelectorAll('h1, h2, h3, [class*="title"], [class*="Title"]'))
    .map(function(e) { return e.tagName + '.' + e.className + '|' + txt(e).slice(0, 60); })
    .filter(function(t) { return t.split('|')[1]; }).slice(0, 25);
  // 決済欄（カード情報）は出力対象から外す
  var clone = document.body.cloneNode(true);
  Array.prototype.forEach.call(
      clone.querySelectorAll('[class*="Paysel"], [class*="Payment"], input, select'),
      function(e) { e.parentNode.removeChild(e); });
  var body = txt(clone);
  var times = [];
  var re = /\d{1,2}(?::|時)\d{2}/g, m;
  while ((m = re.exec(body)) && times.length < 20) {
    times.push(body.slice(Math.max(0, m.index - 40), m.index + 30));
  }
  var trains = [];
  var tre = /[^\s。]{0,20}[0-9０-９]{1,3}号[^\s。]{0,10}/g;
  while ((m = tre.exec(body)) && trains.length < 15) trains.push(m[0]);
  var forms = Array.prototype.slice.call(document.forms)
    .map(function(f) { return f.id + '->' + f.action.replace(location.origin, ''); }).slice(0, 15);
  var buttons = Array.prototype.slice.call(
      document.querySelectorAll('button, input[type=submit], input[type=button], a.btn, [class*="btn"]'))
    .map(function(e) { return (e.value || txt(e)).slice(0, 30); })
    .filter(function(t) { return t; }).slice(0, 25);
  return JSON.stringify({url: location.href, title: document.title, heads: heads,
    times: times, trains: trains, forms: forms, buttons: buttons});
})()
''');
      var raw = result.toString();
      // Android は JSON 文字列をさらに文字列リテラルとして返すことがある
      if (raw.startsWith('"')) raw = jsonDecode(raw) as String;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      debugPrint('EKINET_PAGE_BEGIN $url');
      for (final e in map.entries) {
        final v = e.value;
        if (v is List) {
          for (var i = 0; i < v.length; i++) {
            debugPrint('EKINET_PAGE ${e.key}[$i]: ${v[i]}');
          }
        } else {
          debugPrint('EKINET_PAGE ${e.key}: $v');
        }
      }
      debugPrint('EKINET_PAGE_END');
    } catch (e) {
      debugPrint('EKINET_PAGE_ERROR $url $e');
    }
  }

  Future<bool> _isFormReady() async {
    try {
      final result =
          await _controller.runJavaScriptReturningResult(Ekinet.formReadyScript);
      return result.toString() == 'true';
    } catch (_) {
      // ドキュメント生成前などで評価できない間は「未準備」とみなす
      return false;
    }
  }

  Future<void> _autofillIfSearchPage(String url) async {
    // 検索条件入力ページ以外（ログイン後の遷移先など）では何もしない
    if (_filled || !Ekinet.isSearchPage(url)) return;
    _filled = true;
    await _controller
        .runJavaScript(Ekinet.buildAutofillScript(widget.routeInfo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('検索条件を自動入力しました。内容を確認して「列車を検索する」を押してください'),
      duration: Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 戻る操作（AppBar・システムバック）のどちらでも判定結果を返して閉じる
    return PopScope<ReservationOutcome>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_tracker.outcome());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('えきねっと'),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
