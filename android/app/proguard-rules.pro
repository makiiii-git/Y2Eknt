# アプリ独自の R8（ProGuard）ルール。
#
# Flutter Gradle プラグインがこのファイルを release ビルドの R8 設定として
# 自動で指定する。AGP 9 からはファイルが存在しないとビルドエラーになるため、
# 追加ルールが無くても空のまま置いておく。
# Flutter エンジンと各プラグインに必要なルールは、それぞれのライブラリに同梱
# されている consumer ルールで適用される。

# Room（Google 広告 SDK が使う androidx.work の内部 DB）はデータベース実装クラス
# （例: androidx.work.impl.WorkDatabase_Impl）を引数なしコンストラクタから
# リフレクションで生成する。Room 2.2.5 同梱のルールはクラス名しか保持しないため、
# AGP 9 の R8 ではコンストラクタが削除され、起動直後にクラッシュする
# （2026-10-08 Pixel 7 のリリースビルドで再現）。
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
