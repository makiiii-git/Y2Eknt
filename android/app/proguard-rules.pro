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

# MainActivity の enableEdgeToEdge() 呼び出しを、R8 にインライン化・改名させない。
# Play Console の「一部のユーザーでエッジ ツー エッジ表示が有効にならないことが
# あります」はバイトコード上の EdgeToEdge.enable 呼び出しを静的に探す。R8 が本体を
# MainActivity.onCreate に埋め込み androidx.activity.EdgeToEdge を改名すると、
# 実際には有効になっていても検出されず警告が残る（1.0.8 で確認。flutter/flutter#192921）。
-keep class androidx.activity.EdgeToEdge {
    public static *** enable*(...);
}
# 呼び出しのシグネチャが元の型名のまま読めるよう、引数の型名も残す
-keepnames class androidx.activity.ComponentActivity
-keepnames class androidx.activity.SystemBarStyle
