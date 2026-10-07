import 'package:flutter/material.dart';

import 'ekinet_reservation.dart';
import 'route_history.dart';
import 'route_parser.dart';

/// 申込結果ごとの表示（文言・アイコン・色）。履歴一覧・詳細・結果ダイアログで共用する。
///
/// 配色は「淡い単色の背景 ＋ 濃いめの同系色の文字・アイコン」。
/// Material 3 のカード表面色に半透明の色を重ねると灰色がかって読みにくいため、
/// 背景色は不透明で指定し、カードの表面ティントも無効にする。
class ReservationStatusStyle {
  const ReservationStatusStyle._(
      this.label, this.icon, this.color, this.background);

  final String label;
  final IconData icon;

  /// 文字・アイコンの色（濃いめ）。履歴一覧のアイコンにも使う。
  final Color color;

  /// バナーの背景色（淡い不透明色）。
  final Color background;

  /// [ReservationStatus.unknown] は表示しないため null。
  static ReservationStatusStyle? of(ReservationStatus status) =>
      switch (status) {
        ReservationStatus.unknown => null,
        ReservationStatus.reserved => const ReservationStatusStyle._(
            '共有どおりの列車で申込完了',
            Icons.check_circle,
            Color(0xFF0B7A33),
            Color(0xFFE3F5E8)),
        ReservationStatus.reservedOtherTrain => const ReservationStatusStyle._(
            '別の列車で申込完了',
            Icons.swap_horiz,
            Color(0xFFC2410C),
            Color(0xFFFFF0E0)),
        ReservationStatus.cancelled => const ReservationStatusStyle._(
            '申込を完了せずに終了',
            Icons.cancel,
            Color(0xFF616161),
            Color(0xFFEFEFEF)),
      };
}

/// 履歴の申込結果を示すバナー（経路詳細の上部）。未判定なら何も表示しない。
class ReservationStatusBanner extends StatelessWidget {
  const ReservationStatusBanner({super.key, required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final style = ReservationStatusStyle.of(entry.status);
    if (style == null) return const SizedBox.shrink();
    final detail = [
      if (entry.reservedTrain != null) entry.reservedTrain!,
      if (entry.reservedDepartureTime != null)
        '${entry.reservedDepartureTime}発',
    ].join(' ');
    return Card(
      color: style.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: style.color.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Icon(style.icon, color: style.color, size: 28),
        title: Text(
          style.label,
          style: TextStyle(color: style.color, fontWeight: FontWeight.bold),
        ),
        subtitle: detail.isEmpty
            ? null
            : Text(
                '申込内容: $detail',
                style: const TextStyle(color: Color(0xFF333333)),
              ),
      ),
    );
  }
}

/// えきねっとの WebView を閉じたあとに自動判定の結果をポップアップで見せ、
/// 必要なら選び直してもらってから履歴に記録する。
///
/// 「申込内容の確認」に達していない場合（[ReservationOutcome.shouldRecord] が
/// false）は、検索や空席確認だけの利用なので何も表示せず記録もしない。
Future<void> showReservationResultDialog(
  BuildContext context, {
  required String text,
  required RouteInfo info,
  required ReservationOutcome outcome,
}) async {
  if (!outcome.shouldRecord) return;
  final chosen = await showDialog<ReservationStatus>(
    context: context,
    builder: (_) => _ReservationResultDialog(info: info, outcome: outcome),
  );
  if (chosen == null) return;
  await RouteHistory.updateStatus(
    text,
    chosen,
    reservedTrain: outcome.reservedTrain,
    reservedDepartureTime: outcome.reservedDepartureTime,
  );
}

class _ReservationResultDialog extends StatefulWidget {
  const _ReservationResultDialog({required this.info, required this.outcome});

  final RouteInfo info;
  final ReservationOutcome outcome;

  @override
  State<_ReservationResultDialog> createState() =>
      _ReservationResultDialogState();
}

class _ReservationResultDialogState extends State<_ReservationResultDialog> {
  late ReservationStatus _selected = widget.outcome.status;

  /// 自動判定の結果を説明する文。
  String get _summary {
    final o = widget.outcome;
    final train = [
      if (o.reservedTrain != null) o.reservedTrain!,
      if (o.reservedDepartureTime != null) '${o.reservedDepartureTime}発',
    ].join(' ');
    final trainNote = train.isEmpty ? '' : '（$train）';
    // 完了ページまで検知できていなければ「確認画面まで進んだ＝確定した」前提
    final basis = o.completionDetected
        ? '申込が完了しました。'
        : '申込内容の確認まで進みました（確定したものとして記録します。'
            '確定していなければ「記録しない」を押してください）。';
    switch (o.status) {
      case ReservationStatus.reserved:
        if (!o.itineraryVerified) {
          return '$basis\n列車が共有どおりかは照合できませんでした。';
        }
        return '共有どおりの列車$trainNoteです。$basis';
      case ReservationStatus.reservedOtherTrain:
        final shared = widget.info.jrSegment.departureTime;
        return '共有した${shared != null ? '$shared発' : '列車'}とは別の列車$trainNote'
            'です。$basis';
      case ReservationStatus.cancelled:
        return '申込を完了せずにえきねっとを閉じました。';
      case ReservationStatus.unknown:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('えきねっとの申込結果'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_summary),
            const SizedBox(height: 12),
            Text('違う場合は選び直してください', style: textTheme.bodySmall),
            RadioGroup<ReservationStatus>(
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) setState(() => _selected = v);
              },
              child: Column(
                children: [
                  for (final s in const [
                    ReservationStatus.reserved,
                    ReservationStatus.reservedOtherTrain,
                  ])
                    RadioListTile<ReservationStatus>(
                      value: s,
                      title: Text(ReservationStatusStyle.of(s)!.label),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('記録しない'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
