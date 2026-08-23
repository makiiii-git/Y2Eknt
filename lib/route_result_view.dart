import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ekinet_webview_page.dart';
import 'ex_webview_page.dart';
import 'route_parser.dart';

/// 経路テキストの解析結果と予約サービスへのボタンを表示するビュー。
/// ホーム画面（共有直後）と履歴詳細画面で共用する。
class RouteResultView extends StatelessWidget {
  const RouteResultView({
    super.key,
    required this.text,
    required this.exEnabled,
  });

  /// 共有された経路テキスト原文。
  final String text;

  /// EX予約連携（Web版）が設定で有効か。
  final bool exEnabled;

  Future<void> _copyText(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('テキストをコピーしました')));
  }

  /// カレンダーアプリの予定作成画面を開く（乗車日・時刻・経路入り）。
  /// 毎回アプリ選択ダイアログを表示し、Googleカレンダー・Outlookなど
  /// 登録先をその都度選べるようにする。
  Future<void> _addToCalendar(RouteInfo info) async {
    DateTime parseTime(String hhmm, DateTime base) {
      final p = hhmm.split(':');
      return DateTime(
          base.year, base.month, base.day, int.parse(p[0]), int.parse(p[1]));
    }

    final day = DateTime(info.year!, info.month!, info.day!);
    final start = info.departureTime != null
        ? parseTime(info.departureTime!, day)
        : day.add(const Duration(hours: 9));
    var end = info.arrivalTime != null
        ? parseTime(info.arrivalTime!, day)
        : start.add(const Duration(hours: 2));
    if (!end.isAfter(start)) {
      // 日をまたぐ到着（夜行など）は翌日扱い
      end = end.add(const Duration(days: 1));
    }
    final trainNames = info.legs
        .map((l) => l.trainName)
        .whereType<String>()
        .where((t) => t.contains('新幹線') || t.contains('特急'))
        .join(' / ');
    final intent = AndroidIntent(
      action: 'android.intent.action.INSERT',
      type: 'vnd.android.cursor.item/event',
      arguments: {
        'title': '${info.departureStation} → ${info.arrivalStation}'
            '${trainNames.isNotEmpty ? '（$trainNames）' : ''}',
        'description': text,
        'eventLocation': '${info.departureStation}駅',
        // CalendarContract.EXTRA_EVENT_BEGIN_TIME / END_TIME (long)
        'beginTime': start.millisecondsSinceEpoch,
        'endTime': end.millisecondsSinceEpoch,
      },
    );
    await intent.launchChooser('カレンダーに登録');
  }

  /// 予約サービスへのボタン群。経路の列車に応じて優先順を入れ替える。
  List<Widget> _buildServiceButtons(BuildContext context, RouteInfo info) {
    final ekinetButton = _ServiceButton(
      icon: Icons.train,
      label: 'えきねっとで検索（条件を自動入力）',
      primary: !exEnabled || !info.usesTokaidoSanyoKyushu,
      color: const Color(0xFF00A044), // えきねっとグリーン
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EkinetWebViewPage(routeInfo: info),
        ));
      },
    );
    final exButton = _ServiceButton(
      icon: Icons.directions_railway,
      label: 'EX予約 Web版で検索（東海道・山陽新幹線）',
      primary: info.usesTokaidoSanyoKyushu,
      color: const Color(0xFF0053A6), // EX予約ブルー
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ExWebViewPage(routeInfo: info),
        ));
      },
    );
    if (!exEnabled) return [ekinetButton];
    return info.usesTokaidoSanyoKyushu
        ? [exButton, const SizedBox(height: 8), ekinetButton]
        : [ekinetButton, const SizedBox(height: 8), exButton];
  }

  @override
  Widget build(BuildContext context) {
    final result = RouteParser.parse(text);
    final info = result.routeInfo;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (info != null) ...[
          RouteSummaryCard(info: info),
          const SizedBox(height: 16),
          ..._buildServiceButtons(context, info),
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
        if (info != null && info.year != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: const Text('カレンダーに登録'),
              onPressed: () => _addToCalendar(info),
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('テキストをコピー'),
          onPressed: () => _copyText(context),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('受信したテキスト'),
          initiallyExpanded: info == null,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(text),
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

/// 経路サマリーカード（予約対象のJR区間表示つき）。
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({super.key, required this.info});

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
    // 地下鉄・私鉄のアクセス区間を除いたJR区間が経路全体と異なる場合に表示
    final seg = info.jrSegment;
    final showJrSegment = seg.fromStation != info.departureStation ||
        seg.toStation != info.arrivalStation;
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
            if (showJrSegment)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '予約対象（JR区間）: ${seg.fromStation} → ${seg.toStation}'
                  '${seg.departureTime != null ? '  ${seg.departureTime}発' : ''}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
