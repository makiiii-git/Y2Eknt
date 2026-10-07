import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 予約サービス（WebView）を閉じたときに自動判定して記録する申込の結果。
enum ReservationStatus {
  /// 未判定。予約サービスをまだ開いていない、または判定できなかった。
  unknown,

  /// 共有した経路どおりの列車で申込が完了した。
  reserved,

  /// 共有した経路と違う列車で申込が完了した（満席で変更した場合など）。
  reservedOtherTrain,

  /// 申込を完了せずに予約サービスを閉じた。
  cancelled;

  static ReservationStatus parse(String? name) => ReservationStatus.values
      .firstWhere((s) => s.name == name, orElse: () => ReservationStatus.unknown);

  /// 申込が完了している（列車が共有どおりかは問わない）。
  bool get isReserved =>
      this == ReservationStatus.reserved ||
      this == ReservationStatus.reservedOtherTrain;
}

/// 検索履歴の1件。共有テキスト原文を保持し、表示時に再パースする。
class HistoryEntry {
  const HistoryEntry({
    required this.text,
    required this.receivedAt,
    this.status = ReservationStatus.unknown,
    this.reservedTrain,
    this.reservedDepartureTime,
  });

  final String text;
  final DateTime receivedAt;

  /// 予約サービスでの申込結果。
  final ReservationStatus status;

  /// 実際に申し込んだ列車名（完了画面から読み取れた場合。例: はやぶさ21号）。
  final String? reservedTrain;

  /// 実際に申し込んだ列車の発時刻（"12:20" 形式。読み取れた場合）。
  final String? reservedDepartureTime;

  HistoryEntry copyWith({
    ReservationStatus? status,
    String? reservedTrain,
    String? reservedDepartureTime,
  }) =>
      HistoryEntry(
        text: text,
        receivedAt: receivedAt,
        status: status ?? this.status,
        reservedTrain: reservedTrain ?? this.reservedTrain,
        reservedDepartureTime:
            reservedDepartureTime ?? this.reservedDepartureTime,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'receivedAt': receivedAt.toIso8601String(),
        if (status != ReservationStatus.unknown) 'status': status.name,
        if (reservedTrain != null) 'reservedTrain': reservedTrain,
        if (reservedDepartureTime != null)
          'reservedDepartureTime': reservedDepartureTime,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        text: json['text'] as String,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        status: ReservationStatus.parse(json['status'] as String?),
        reservedTrain: json['reservedTrain'] as String?,
        reservedDepartureTime: json['reservedDepartureTime'] as String?,
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
  /// 再共有は新しい申込の試みとみなし、申込結果は未判定に戻す。
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

  /// 指定テキストの履歴に申込結果を記録する。履歴に無ければ何もしない。
  static Future<void> updateStatus(
    String text,
    ReservationStatus status, {
    String? reservedTrain,
    String? reservedDepartureTime,
  }) async {
    final entries = await load();
    final i = entries.indexWhere((e) => e.text == text);
    if (i < 0) return;
    entries[i] = HistoryEntry(
      text: entries[i].text,
      receivedAt: entries[i].receivedAt,
      status: status,
      reservedTrain: status.isReserved ? reservedTrain : null,
      reservedDepartureTime: status.isReserved ? reservedDepartureTime : null,
    );
    await _save(entries);
  }

  /// 指定テキストの履歴を返す。無ければ null。
  static Future<HistoryEntry?> find(String text) async {
    final entries = await load();
    for (final e in entries) {
      if (e.text == text) return e;
    }
    return null;
  }

  /// 指定エントリ（テキスト一致）を削除する。
  static Future<void> remove(HistoryEntry entry) async {
    final entries = await load();
    entries.removeWhere((e) => e.text == entry.text);
    await _save(entries);
  }
}
