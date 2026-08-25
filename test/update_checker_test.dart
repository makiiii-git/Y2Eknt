import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:y2eknt/update_checker.dart';

void main() {
  group('UpdateChecker.isNewer', () {
    test('新しいバージョンを検出する', () {
      expect(UpdateChecker.isNewer('0.1.0', '0.2.0'), isTrue);
      expect(UpdateChecker.isNewer('0.2.0', '1.0.0'), isTrue);
      expect(UpdateChecker.isNewer('1.9.9', '2.0.0'), isTrue);
      expect(UpdateChecker.isNewer('0.2.0', '0.2.1'), isTrue);
    });

    test('同じ・古いバージョンは false', () {
      expect(UpdateChecker.isNewer('0.2.0', '0.2.0'), isFalse);
      expect(UpdateChecker.isNewer('0.2.0', '0.1.9'), isFalse);
      expect(UpdateChecker.isNewer('1.0.0', '0.9.9'), isFalse);
    });

    test('解釈できない文字列は false', () {
      expect(UpdateChecker.isNewer('0.2.0', 'unknown'), isFalse);
      expect(UpdateChecker.isNewer('', '0.2.0'), isFalse);
    });
  });

  group('UpdateChecker.stripTagPrefix', () {
    test('先頭のV/vを除去する', () {
      expect(UpdateChecker.stripTagPrefix('V0.2.0'), '0.2.0');
      expect(UpdateChecker.stripTagPrefix('v1.0.0'), '1.0.0');
      expect(UpdateChecker.stripTagPrefix('0.2.0'), '0.2.0');
    });
  });

  group('UpdateChecker.fetchLatest のAPK選択', () {
    UpdateChecker checkerWithAssets(List<String> names) {
      return UpdateChecker(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'tag_name': 'V1.0.4',
                'html_url': 'https://example.com/release',
                'assets': [
                  for (final n in names)
                    {'browser_download_url': 'https://example.com/$n'},
                ],
              }),
              200,
            )),
      );
    }

    test('ABI別のAPKが並んでいてもarm64版を選ぶ', () async {
      // GitHubはファイル名順に返すため -arm32 が先に来る
      final latest = await checkerWithAssets(
              ['Y2Eknt-v1.0.4-arm32.apk', 'Y2Eknt-v1.0.4.apk'])
          .fetchLatest();
      expect(latest!.apkUrl, endsWith('Y2Eknt-v1.0.4.apk'));
    });

    test('APKが1つならそれを選ぶ', () async {
      final latest =
          await checkerWithAssets(['Y2Eknt-v1.0.4.apk']).fetchLatest();
      expect(latest!.apkUrl, endsWith('Y2Eknt-v1.0.4.apk'));
    });

    test('APKが無ければnull', () async {
      final latest = await checkerWithAssets(['sources.zip']).fetchLatest();
      expect(latest!.apkUrl, isNull);
    });
  });
}
