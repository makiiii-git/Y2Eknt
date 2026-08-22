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
  late final WebViewController _controller;
  bool _filled = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (url) => _autofillIfSearchPage(url),
      ))
      ..loadRequest(Uri.parse(Ekinet.searchPageUrl));
  }

  Future<void> _autofillIfSearchPage(String url) async {
    // 検索条件入力ページ以外（ログイン後の遷移先など）では何もしない
    if (_filled || !url.contains('RouteSearchConditionInput')) return;
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
