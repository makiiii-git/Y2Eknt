/// ビルド種別による機能の出し分け。
///
/// Google Play 版は `--dart-define=PLAY_STORE=true` を付けてビルドする。
///
/// **Play版のみ**:
/// - バナー広告（AdMobは承認済みストア経由の配布が前提のため）
/// - アプリ内課金によるプレミアム解除
///
/// **GitHub版（フラグなし）のみ**:
/// - GitHub Releases からのAPK更新チェック
///   （Play外からのアプリ更新はPlayポリシーで禁止されている）
/// - ソースコードリポジトリへのリンク
///
/// GitHub版は Play Billing が使えず課金できないため、
/// プレミアム機能（履歴無制限・自動で開く・EX予約連携）は最初から解放する。
const bool kIsPlayStoreBuild = bool.fromEnvironment('PLAY_STORE');
