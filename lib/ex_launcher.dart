import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'route_parser.dart';

/// EX予約（EXアプリ）連携。
///
/// EXアプリ (jp.co.jr_central.exreserve) は
/// https://shinkansen1.jr-central.co.jp/RSV_P/ex_index.htm への
/// App Link（RouteSearchActivityAlias = 経路検索画面）を持つため、
/// このURLを開くとEXアプリの検索画面が直接起動する（2026-08 実機調査）。
/// 検索条件を外部から渡す手段は無いため、経路サマリーをクリップボードへ
/// コピーして入力を補助する。未インストール時はブラウザでログインページが開く。
class ExLauncher {
  static const String routeSearchUrl =
      'https://shinkansen1.jr-central.co.jp/RSV_P/ex_index.htm';

  /// EXアプリの検索フォームに貼り付けやすい経路サマリー。
  /// 駅と時刻はアクセス区間（地下鉄・私鉄）を除いたJR区間を使う。
  static String buildSummary(RouteInfo info) {
    final seg = info.jrSegment;
    final buf = StringBuffer('${seg.fromStation} → ${seg.toStation}');
    if (info.year != null) {
      buf.write('\n${info.year}/${info.month}/${info.day}');
    }
    if (seg.departureTime != null) {
      buf.write(' ${seg.departureTime}発');
    }
    return buf.toString();
  }

  /// 経路サマリーをコピーしてからEXアプリ（無ければブラウザ）を開く。
  static Future<void> launch(RouteInfo info) async {
    await Clipboard.setData(ClipboardData(text: buildSummary(info)));
    final uri = Uri.parse(routeSearchUrl);
    // まずEXアプリ（非ブラウザ）を試し、無ければ外部ブラウザで開く
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalNonBrowserApplication,
    ).then((ok) => ok, onError: (_) => false);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
