/// ビルド種別による機能の出し分け。
///
/// Google Play 版は `--dart-define=PLAY_STORE=true` を付けてビルドする。
/// Play 版では次の機能を無効にする:
/// - GitHub Releases からのAPK更新チェック
///   （Play外からのアプリ更新はPlayポリシーで禁止されている）
/// - ソースコードリポジトリへのリンク
///
/// GitHub Releases 用のAPKビルドではフラグを付けないため、
/// 従来どおり更新チェックとリンクが表示される。
const bool kIsPlayStoreBuild = bool.fromEnvironment('PLAY_STORE');
