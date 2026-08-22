import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:y2eknt/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings.exEnabled', () {
    test('既定は無効', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppSettings.getExEnabled(), isFalse);
    });

    test('有効化を保存・取得できる', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.setExEnabled(true);
      expect(await AppSettings.getExEnabled(), isTrue);
      await AppSettings.setExEnabled(false);
      expect(await AppSettings.getExEnabled(), isFalse);
    });
  });

  group('AppSettings.autoOpen', () {
    test('既定はボタンで開く（無効）', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppSettings.getAutoOpen(), isFalse);
    });

    test('自動モードを保存・取得できる', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.setAutoOpen(true);
      expect(await AppSettings.getAutoOpen(), isTrue);
    });
  });
}
