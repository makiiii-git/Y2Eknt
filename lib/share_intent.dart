import 'package:flutter/services.dart';

/// MainActivity (Android) から共有テキストを受け取る MethodChannel ラッパー。
class ShareIntent {
  static const MethodChannel _channel =
      MethodChannel('io.github.makiiii_git.y2eknt/share');

  /// コールドスタート時に共有されたテキストを取得する。共有起動でなければ null。
  static Future<String?> getInitialText() {
    return _channel.invokeMethod<String>('getSharedText');
  }

  /// アプリ起動中に新たに共有されたテキストを受け取るハンドラを登録する。
  static void setOnSharedText(void Function(String text) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        final text = call.arguments as String?;
        if (text != null) {
          handler(text);
        }
      }
    });
  }
}
