import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 検索履歴の1件。共有テキスト原文を保持し、表示時に再パースする。
class HistoryEntry {
  const HistoryEntry({required this.text, required this.receivedAt});

  final String text;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => {
        'text': text,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        text: json['text'] as String,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
      );
}

/// 検索履歴の永続化（端末内のみ）。新しい順に保持する。
class RouteHistory {
  static const _key = 'route_history';
  static const maxEntries = 20;

  static Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// 先頭に追加する。同じテキストの既存エントリは重複させず先頭へ移動。
  /// [maxEntries] を超えた分は古い順に削除。
  static Future<void> add(String text, {DateTime? receivedAt}) async {
    final entries = await load();
    entries.removeWhere((e) => e.text == text);
    entries.insert(
        0, HistoryEntry(text: text, receivedAt: receivedAt ?? DateTime.now()));
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
    await _save(entries);
  }

  /// 指定エントリ（テキスト一致）を削除する。
  static Future<void> remove(HistoryEntry entry) async {
    final entries = await load();
    entries.removeWhere((e) => e.text == entry.text);
    await _save(entries);
  }
}
