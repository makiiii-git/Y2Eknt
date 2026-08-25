import 'dart:convert';

import 'package:http/http.dart' as http;

/// GitHub Releases の最新リリース情報。
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.pageUrl,
    this.apkUrl,
  });

  /// タグから先頭の V を除いたバージョン（例: "0.2.0"）。
  final String version;

  /// リリースページのURL。
  final String pageUrl;

  /// APKアセットの直接ダウンロードURL（存在する場合）。
  final String? apkUrl;
}

/// GitHub Releases を使った更新チェック。
class UpdateChecker {
  UpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  static const String repo = 'makiiii-git/Y2Eknt';

  final http.Client _client;

  /// 最新リリースを取得する。リリースが存在しない場合は null。
  Future<ReleaseInfo?> fetchLatest() async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('更新情報の取得に失敗しました (HTTP ${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) return null;

    // 標準APK（arm64）を選ぶ。ABI別のAPKが併存する場合、GitHubは
    // ファイル名順に返すため単純な先頭一致だと32bit版を掴んでしまう。
    final urls = (json['assets'] as List<dynamic>? ?? const [])
        .map((a) => (a as Map<String, dynamic>)['browser_download_url'])
        .whereType<String>()
        .where((url) => url.endsWith('.apk'))
        .toList();
    final apkUrl = urls.firstWhere(
      (url) => !RegExp(r'arm32|armeabi|x86').hasMatch(url),
      orElse: () => urls.isEmpty ? '' : urls.first,
    );
    return ReleaseInfo(
      version: stripTagPrefix(tag),
      pageUrl: json['html_url'] as String? ?? 'https://github.com/$repo/releases',
      apkUrl: apkUrl.isEmpty ? null : apkUrl,
    );
  }

  /// "V0.2.0" → "0.2.0"
  static String stripTagPrefix(String tag) =>
      tag.replaceFirst(RegExp(r'^[vV]'), '');

  /// [latest] が [current] より新しいか（"x.y.z" 数値比較）。
  /// 解釈できない場合は false。
  static bool isNewer(String current, String latest) {
    List<int>? parse(String s) {
      final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(s.trim());
      if (m == null) return null;
      return [1, 2, 3].map((i) => int.parse(m.group(i)!)).toList();
    }

    final c = parse(current);
    final l = parse(latest);
    if (c == null || l == null) return false;
    for (var i = 0; i < 3; i++) {
      if (l[i] != c[i]) return l[i] > c[i];
    }
    return false;
  }
}
