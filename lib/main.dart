import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ekinet_webview_page.dart';
import 'ex_launcher.dart';
import 'route_parser.dart';
import 'settings_page.dart';
import 'share_intent.dart';

void main() {
  runApp(const Y2EkinetApp());
}

class Y2EkinetApp extends StatelessWidget {
  const Y2EkinetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Y2Ekinet',
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
  ParseResult? _parseResult;

  @override
  void initState() {
    super.initState();
    _loadInitialText();
    ShareIntent.setOnSharedText(_onText);
  }

  Future<void> _loadInitialText() async {
    final text = await ShareIntent.getInitialText();
    if (text != null && mounted) {
      _onText(text);
    }
  }

  void _onText(String text) {
    debugPrint('SHARED_TEXT_BEGIN\n$text\nSHARED_TEXT_END');
    setState(() {
      _sharedText = text;
      _parseResult = RouteParser.parse(text);
    });
  }

  Future<void> _openExApp(RouteInfo info) async {
    // アプリがバックグラウンドに回る前に案内を出す
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('経路情報をコピーしました。EXアプリの検索画面に貼り付けてご利用ください'),
    ));
    await ExLauncher.launch(info);
  }

  Future<void> _copyText() async {
    final text = _sharedText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('テキストをコピーしました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Y2Ekinet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SettingsPage(),
              ));
            },
          ),
        ],
      ),
      body: _sharedText == null ? _buildEmpty() : _buildResult(),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Yahoo!乗換案内の経路詳細画面から\n「共有」→「他のアプリに共有」で\nY2Ekinetにテキストを送ってください',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 予約サービスへのボタン群。経路の列車に応じて優先順を入れ替える。
  List<Widget> _buildServiceButtons(RouteInfo info) {
    final ekinetButton = _ServiceButton(
      icon: Icons.train,
      label: 'えきねっとで検索（条件を自動入力）',
      primary: !info.usesTokaidoSanyoKyushu,
      color: const Color(0xFF00A044), // えきねっとグリーン
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EkinetWebViewPage(routeInfo: info),
        ));
      },
    );
    final exButton = _ServiceButton(
      icon: Icons.directions_railway,
      label: 'EXアプリで開く（東海道・山陽・九州新幹線）',
      primary: info.usesTokaidoSanyoKyushu,
      color: const Color(0xFF0053A6), // EX予約ブルー
      onPressed: () => _openExApp(info),
    );
    return info.usesTokaidoSanyoKyushu
        ? [exButton, const SizedBox(height: 8), ekinetButton]
        : [ekinetButton, const SizedBox(height: 8), exButton];
  }

  Widget _buildResult() {
    final result = _parseResult!;
    final info = result.routeInfo;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (info != null) ...[
          _RouteSummaryCard(info: info),
          const SizedBox(height: 16),
          ..._buildServiceButtons(info),
        ] else ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('経路を解析できませんでした：${result.error}\n'
                  '下のテキストをコピーして、えきねっとに手動で入力してください。'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('テキストをコピー'),
          onPressed: _copyText,
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('受信したテキスト'),
          initiallyExpanded: info == null,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_sharedText!),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool primary;

  /// サービスのブランドカラー（えきねっと=緑、EX予約=青）。
  final Color color;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 優先ボタンは濃色地に白文字、非優先は淡色地にブランド色文字
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white)
        : FilledButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color);
    return FilledButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: style,
      onPressed: onPressed,
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({required this.info});

  final RouteInfo info;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = (info.year != null)
        ? '${info.year}年${info.month}月${info.day}日'
        : null;
    final time = (info.departureTime != null)
        ? '${info.departureTime} 発 → ${info.arrivalTime ?? '?'} 着'
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${info.departureStation} → ${info.arrivalStation}',
              style: textTheme.titleLarge,
            ),
            if (date != null) Text(date, style: textTheme.bodyLarge),
            if (time != null) Text(time, style: textTheme.bodyLarge),
            if (info.legs.isNotEmpty) ...[
              const Divider(),
              for (final leg in info.legs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${leg.fromStation} → ${leg.toStation}'
                    '${leg.departureTime != null ? '  ${leg.departureTime}〜${leg.arrivalTime}' : ''}'
                    '${leg.trainName != null ? '\n${leg.trainName}' : ''}',
                    style: textTheme.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
