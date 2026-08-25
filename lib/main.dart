import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'ad_banner.dart';
import 'app_settings.dart';
import 'build_config.dart';
import 'ekinet_webview_page.dart';
import 'ex_webview_page.dart';
import 'history_detail_page.dart';
import 'premium.dart';
import 'route_history.dart';
import 'route_parser.dart';
import 'route_result_view.dart';
import 'settings_page.dart';
import 'share_intent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 開発時のみWebViewをChrome DevToolsで検証できるようにする
  if (kDebugMode) {
    AndroidWebViewController.enableDebugging(true);
  }
  // 購入状態の復元と広告SDKの初期化は起動をブロックせずに進める
  PremiumManager.instance.init();
  // 広告はPlay版のみ（AdMobは承認済みストア経由の配布が前提）
  if (kIsPlayStoreBuild) {
    MobileAds.instance.initialize();
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

  /// 設定画面でのEX連携のON/OFF。実際に有効かは[_isExActive]で判定する。
  bool _exSetting = false;
  List<HistoryEntry> _history = [];

  /// EX予約連携はプレミアム限定。設定がONでも無料版では無効。
  bool get _isExActive => _exSetting && PremiumManager.instance.isPremium.value;

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
    if (mounted) setState(() => _exSetting = exEnabled);
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
    final result = RouteParser.parse(text);
    setState(() => _sharedText = text);
    if (result.isSuccess) {
      await RouteHistory.add(text);
      await _loadHistory();
    }
    final info = result.routeInfo;
    // 自動で開くはプレミアム限定（購入前に設定済みでも無料時は無効）
    if (info != null &&
        PremiumManager.instance.isPremium.value &&
        await AppSettings.getAutoOpen()) {
      // 起動直後でも確実に判定できるよう設定を直接読む
      final exEnabled = await AppSettings.getExEnabled();
      _autoOpen(
          info,
          exEnabled &&
              PremiumManager.instance.isPremium.value &&
              info.usesTokaidoSanyoKyushu);
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
      builder: (_) => HistoryDetailPage(entry: entry, exEnabled: _isExActive),
    ));
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumManager.instance.isPremium,
      builder: (context, isPremium, _) => _buildScaffold(context, isPremium),
    );
  }

  Widget _buildScaffold(BuildContext context, bool isPremium) {
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
              history: isPremium
                  ? _history
                  : _history.take(PremiumManager.freeHistoryLimit).toList(),
              lockedCount: isPremium
                  ? 0
                  : _history.length - PremiumManager.freeHistoryLimit,
              onTapEntry: _openHistoryDetail,
              onDeleteEntry: (entry) async {
                await RouteHistory.remove(entry);
                _loadHistory();
              },
              onTapLocked: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ));
                _loadSettings();
              },
            )
          : RouteResultView(text: _sharedText!, exEnabled: _isExActive),
      // 無料版のみホーム画面下部にバナー広告を表示する
      bottomNavigationBar:
          (!isPremium && _sharedText == null) ? const AdBanner() : null,
    );
  }
}

/// ホーム画面: 使い方の案内と検索履歴カードの一覧。
class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.history,
    required this.lockedCount,
    required this.onTapEntry,
    required this.onDeleteEntry,
    required this.onTapLocked,
  });

  final List<HistoryEntry> history;

  /// 無料版の表示上限で隠れている履歴の件数（プレミアムなら0）。
  final int lockedCount;
  final void Function(HistoryEntry) onTapEntry;
  final void Function(HistoryEntry) onDeleteEntry;
  final VoidCallback onTapLocked;

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
        else ...[
          for (final entry in history)
            _HistoryCard(
              entry: entry,
              onTap: () => onTapEntry(entry),
              onDelete: () => onDeleteEntry(entry),
            ),
          if (lockedCount > 0)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text('ほかに$lockedCount件の履歴があります'),
              subtitle: const Text('プレミアムにアップグレードするとすべて表示できます'),
              onTap: onTapLocked,
            ),
        ],
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
