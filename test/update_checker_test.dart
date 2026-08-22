import 'package:flutter_test/flutter_test.dart';

import 'package:y2ekinet/update_checker.dart';

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
}
