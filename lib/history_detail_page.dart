import 'package:flutter/material.dart';

import 'route_history.dart';
import 'route_result_view.dart';

/// 検索履歴の詳細画面。解析結果と予約サービスへのボタンを表示する。
class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({
    super.key,
    required this.entry,
    required this.exEnabled,
  });

  final HistoryEntry entry;
  final bool exEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('検索履歴'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'この履歴を削除',
            onPressed: () async {
              await RouteHistory.remove(entry);
              if (context.mounted) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: RouteResultView(text: entry.text, exEnabled: exEnabled),
    );
  }
}
