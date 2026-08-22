import 'package:shared_preferences/shared_preferences.dart';

/// アプリ設定の永続化。
class AppSettings {
  static const _keyExEnabled = 'ex_integration_enabled';

  /// EXアプリ連携（バックアップ機能）を有効にするか。既定は無効。
  ///
  /// スマートEXはYahoo!乗換案内が公式連携済みであり、本アプリのEX連携は
  /// 条件の引き継ぎができない（経路コピーによる補助のみ）ため、
  /// 既定ではボタンを表示しない。
  static Future<bool> getExEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyExEnabled) ?? false;
  }

  static Future<void> setExEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyExEnabled, value);
  }
}
