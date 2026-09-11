import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ekinet.dart';
import 'route_parser.dart';

/// えきねっとの検索ページを開き、経路情報を自動入力するWebView画面。
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
  bool _filled = false;
  int _progress = 0;

  /// ページ遷移のたびに増やし、古いポーリングを止めるための世代番号。
  int _pollGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        // えきねっとは計測タグの読み込みで load 完了が遅い（10秒超）ため、
        // load を待たずフォームが出現した時点で入力する
        onPageStarted: (url) => _pollFormAndFill(url),
        onPageFinished: (url) => _autofillIfSearchPage(url),
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
    return Scaffold(
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
    );
  }
}
