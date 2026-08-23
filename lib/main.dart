import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app_settings.dart';
import 'ekinet_webview_page.dart';
import 'ex_webview_page.dart';
import 'history_detail_page.dart';
import 'route_history.dart';
import 'route_parser.dart';
import 'route_result_view.dart';
import 'settings_page.dart';
import 'share_intent.dart';

void main() {
  // 開発時のみWebViewをChrome DevToolsで検証できるようにする
  if (kDebugMode) {
    AndroidWebViewController.enableDebugging(true);
  }
  runApp(const Y2EkntApp());
}

class Y2EkntApp extends StatelessWidget {
  const Y2EkntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Y2Eknt',
      theme: ThemeData(
        // えきねっとのブランドカラーに合わせたグリーン
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A044)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _sharedText;
  bool _exEnabled = false;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
    _loadInitialText();
    ShareIntent.setOnSharedText(_onText);
  }

  Future<void> _loadSettings() async {
    final exEnabled = await AppSettings.getExEnabled();
    if (mounted) setState(() => _exEnabled = exEnabled);
  }

  Future<void> _loadHistory() async {
    final history = await RouteHistory.load();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _loadInitialText() async {
    final text = await ShareIntent.getInitialText();
    if (text != null && mounted) {
      _onText(text);
    }
  }

  Future<void> _onText(String text) async {
    debugPrint('SHARED_TEXT_BEGIN\n$text\nSHARED_TEXT_END');
    final result = RouteParser.parse(text);
    setState(() => _sharedText = text);
    if (result.isSuccess) {
      await RouteHistory.add(text);
      await _loadHistory();
    }
    final info = result.routeInfo;
    if (info != null && await AppSettings.getAutoOpen()) {
      // 起動直後でも確実に判定できるよう設定を直接読む
      final exEnabled = await AppSettings.getExEnabled();
      _autoOpen(info, exEnabled && info.usesTokaidoSanyoKyushu);
    }
  }

  /// 自動モード: 共有受信後すぐに予約サービスへ遷移する。
  /// 東海道・山陽・九州新幹線の経路はEX予約（連携ON時）、
  /// それ以外はえきねっとへ自動で振り分ける。
  void _autoOpen(RouteInfo info, bool useEx) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    // 連続共有でWebViewが積み重ならないようホームまで戻してから開く
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(
      builder: (_) => useEx
          ? ExWebViewPage(routeInfo: info)
          : EkinetWebViewPage(routeInfo: info),
    ));
  }

  Future<void> _openHistoryDetail(HistoryEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HistoryDetailPage(entry: entry, exEnabled: _exEnabled),
    ));
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Y2Eknt'),
        actions: [
          if (_sharedText != null)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'ホームへ戻る',
              onPressed: () => setState(() => _sharedText = null),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SettingsPage(),
              ));
              // 設定画面でEX連携が切り替えられた場合に反映する
              _loadSettings();
            },
          ),
        ],
      ),
      body: _sharedText == null
          ? _HomeBody(
              history: _history,
              onTapEntry: _openHistoryDetail,
              onDeleteEntry: (entry) async {
                await RouteHistory.remove(entry);
                _loadHistory();
              },
            )
          : RouteResultView(text: _sharedText!, exEnabled: _exEnabled),
    );
  }
}

/// ホーム画面: 使い方の案内と検索履歴カードの一覧。
class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.history,
    required this.onTapEntry,
    required this.onDeleteEntry,
  });

  final List<HistoryEntry> history;
  final void Function(HistoryEntry) onTapEntry;
  final void Function(HistoryEntry) onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Yahoo!乗換案内の経路詳細画面から「共有」→「他のアプリに共有」→ '
              'Y2Eknt でテキストを送ると、予約サービスの検索へつなぎます',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('検索履歴', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '履歴はまだありません',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final entry in history)
            _HistoryCard(
              entry: entry,
              onTap: () => onTapEntry(entry),
              onDelete: () => onDeleteEntry(entry),
            ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final info = RouteParser.parse(entry.text).routeInfo;
    final isEx = info?.usesTokaidoSanyoKyushu ?? false;
    final color =
        isEx ? const Color(0xFF0053A6) : const Color(0xFF00A044);
    final title = info != null
        ? '${info.departureStation} → ${info.arrivalStation}'
        : '（解析できない履歴）';
    final date = (info?.year != null)
        ? '${info!.year}/${info.month}/${info.day}'
        : null;
    final subtitle = [
      if (date != null) date,
      if (info?.departureTime != null) '${info!.departureTime}発',
    ].join('  ');

    return Dismissible(
      key: ValueKey(entry.text.hashCode ^ entry.receivedAt.hashCode),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            isEx ? Icons.directions_railway : Icons.train,
            color: color,
          ),
          title: Text(title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
