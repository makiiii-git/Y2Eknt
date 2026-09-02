# Y2Eknt 引き継ぎ資料

作成日: 2026-09-02
対象リビジョン: `main` @ `4a516c1`（アプリ内更新が32bit版APKを掴む不具合を修正し、配布をarm64のみにする）

この資料は、Y2Eknt の開発・配布・運用を別の担当者が引き継ぐために、リポジトリの内容と現状を一か所にまとめたものです。利用者向けの説明は [README.md](README.md)、ストア掲載文は [store-listing.md](store-listing.md)、テスター募集文は [closed-test-recruit.md](closed-test-recruit.md) を参照してください。

---

## 目次

1. [プロジェクト概要](#1-プロジェクト概要)
2. [現在の状態](#2-現在の状態)
3. [技術スタックと開発環境](#3-技術スタックと開発環境)
4. [リポジトリ構成](#4-リポジトリ構成)
5. [アーキテクチャと処理フロー](#5-アーキテクチャと処理フロー)
6. [モジュール解説](#6-モジュール解説)
7. [GitHub版とGoogle Play版の出し分け](#7-github版とgoogle-play版の出し分け)
8. [外部サイト依存（最も壊れやすい箇所）](#8-外部サイト依存最も壊れやすい箇所)
9. [ビルド・リリース手順](#9-ビルドリリース手順)
10. [Google Play 関連](#10-google-play-関連)
11. [テスト](#11-テスト)
12. [端末内に保存するデータ](#12-端末内に保存するデータ)
13. [既知の課題・注意点・TODO](#13-既知の課題注意点todo)
14. [引き継ぎに必要なアカウント・秘密情報チェックリスト](#14-引き継ぎに必要なアカウント秘密情報チェックリスト)
15. [用語集](#15-用語集)

---

## 1. プロジェクト概要

| 項目 | 内容 |
|---|---|
| アプリ名 | Y2Eknt（ワイツーエキネット） |
| 種別 | Android アプリ（Flutter 製、個人開発・非公式） |
| 目的 | Yahoo!乗換案内の「共有」テキストから出発駅・到着駅・乗車日・時刻を抽出し、えきねっと／EX予約（Web版）の検索フォームに自動入力した状態で開く |
| リポジトリ | https://github.com/makiiii-git/Y2Eknt |
| パッケージID | `io.github.makiiii_git.y2eknt` |
| ライセンス | Apache License 2.0 |
| 配布形態 | (a) GitHub Releases の APK、(b) Google Play（AAB） |
| プライバシーポリシー | https://makiiii-git.github.io/Y2Eknt/privacy-policy.html（`docs/privacy-policy.html` を GitHub Pages で公開） |
| 開発履歴 | 2026-08-22 に着手し、2026-08-25 までの4日間で V1.0.4 まで到達 |

アプリは「検索条件の入力補助」に徹しており、検索ボタンの押下・予約の実行はすべてユーザー自身が行います。開発者側のサーバーは存在せず、アクセス解析も行っていません。

---

## 2. 現在の状態

### バージョン

| 項目 | 値 |
|---|---|
| `pubspec.yaml` の version | `1.0.4+15`（versionName 1.0.4 / versionCode 15） |
| 最新 GitHub Release | V1.0.4（2026-08-25 公開、タグ `68c1e50`） |
| 実際の配布 versionCode | GitHub版 APK は `--split-per-abi` により **2015**（15 + 2000）。詳細は [9章](#9-ビルドリリース手順) |

### 未リリースの変更（重要）

`main` の先頭 `4a516c1` は V1.0.4 タグより後のコミットで、**まだリリースされていません**。内容は次のとおりです。

- アプリ内更新チェック（`lib/update_checker.dart`）が、ABI別 APK が並ぶリリースで 32bit 版を選んでしまう不具合の修正
- CI を arm64 のみのビルドに変更（32bit / x86_64 の APK を作らない）
- README の該当箇所の更新

V1.0.4 の APK には旧ロジックが入っているため、この修正を届けるには `pubspec.yaml` の version を `1.0.5+16` などに上げてタグ `V1.0.5` を打つ必要があります。

### Google Play の状況

リポジトリから確認できる範囲では次のとおりです。**Play Console 上の実際の審査・公開状態はリポジトリからは分からないため、引き継ぎ時に前任者へ確認してください。**

- ストア掲載文（`store-listing.md`）、掲載画像（`store-assets/`）、プライバシーポリシーは準備済み
- クローズドテストのテスター募集文（`closed-test-recruit.md`）は雛形の状態で、Googleグループ URL・オプトイン URL・開始日が「要記入」のまま
- 個人開発者アカウントの製品版公開には「12人以上のテスターで14日間のクローズドテスト」が必要（同ファイルに記載）
- targetSdk 36 対応（2026-08-31 期限）と Billing Library 8 対応は完了済み

### Issue / PR

2026-09-02 時点で、GitHub 上の Issue・Pull Request はいずれも 0 件です。開発はすべて `main` への直接コミットで行われてきました。

---

## 3. 技術スタックと開発環境

| 項目 | 値 | 備考 |
|---|---|---|
| Flutter | 3.38.10 stable | CI（`.github/workflows/build_apk.yml`）で固定。ローカルも同じにする |
| Dart SDK | `^3.10.0` | `in_app_purchase_android` 0.5.0（Billing Library 8）の要件 |
| Java | 17（temurin） | CI 設定。ローカルは JDK 17 以上 |
| Android Gradle Plugin | 8.7.0 | `android/settings.gradle.kts` |
| Kotlin | 2.1.0 | 同上 |
| Gradle | 8.10.2 | `android/gradle/wrapper/gradle-wrapper.properties` |
| compileSdk / targetSdk | 36 | `android/app/build.gradle.kts` |
| minSdk | Flutter 既定（`flutter.minSdkVersion`） | テスター募集文では「Android 7.0 以上」と案内 |
| 対応 ABI | arm64-v8a のみ（GitHub版） | Play版は AAB なので Play が端末ごとに配信 |
| Lint | `flutter_lints` 5.x | `analysis_options.yaml` は既定のまま |

### 主要な依存パッケージ

| パッケージ | 用途 |
|---|---|
| `webview_flutter` / `webview_flutter_android` | えきねっと・EX予約をアプリ内で開き JavaScript を注入する |
| `http` | GitHub API で最新リリースを取得（更新チェック） |
| `package_info_plus` | 現在のバージョン表示 |
| `url_launcher` | 外部ブラウザ・EXアプリ起動・APK ダウンロード |
| `shared_preferences` | 設定・検索履歴・プレミアム状態キャッシュ |
| `flutter_secure_storage` | EX予約ログイン情報の暗号化保存（Android Keystore） |
| `android_intent_plus` | カレンダーの予定作成画面を開く |
| `google_mobile_ads` | バナー広告（Play版のみ） |
| `in_app_purchase` | 買い切り課金（Play版のみ） |
| `flutter_launcher_icons`（dev） | アイコン生成。設定は `pubspec.yaml` 末尾 |

### ローカル環境の準備

```bash
# Flutter 3.38.10 を用意したうえで
flutter pub get
flutter analyze
flutter test
```

`android/local.properties`（`flutter.sdk` のパス）は Flutter ツールが自動生成します。git 管理外です。

---

## 4. リポジトリ構成

```
.
├── .github/workflows/build_apk.yml   CI: analyze / test / APK ビルド / Releases アップロード
├── android/                          Android ネイティブ側
│   └── app/src/main/kotlin/.../MainActivity.kt   共有インテント受信（MethodChannel）
├── assets/icon/                      アイコン元画像（flutter_launcher_icons 用）
├── docs/privacy-policy.html          GitHub Pages で公開するプライバシーポリシー
├── lib/                              Dart ソース（17ファイル、約2,100行）
├── store-assets/                     Play ストア掲載用画像（アイコン・フィーチャーグラフィック・スクショ）
├── test/                             ユニットテスト（6ファイル）
├── README.md                         利用者向け説明
├── store-listing.md                  Play ストア掲載文の下書き
├── closed-test-recruit.md            クローズドテスト募集文の雛形と準備チェックリスト
├── HANDOVER.md                       この資料
├── pubspec.yaml                      バージョン・依存関係
└── LICENSE                           Apache 2.0
```

`docs/` は GitHub Pages の公開ディレクトリとして使われているため、公開したくないファイルは置かないでください。

---

## 5. アーキテクチャと処理フロー

画面遷移とデータの流れは次のとおりです。

```
Yahoo!乗換案内「共有」
        │  ACTION_SEND (text/plain)
        ▼
MainActivity.kt ──MethodChannel──▶ ShareIntent (lib/share_intent.dart)
   （コールドスタート: getSharedText / 起動中: onSharedText）
        │
        ▼
HomePage._onText (lib/main.dart)
        │  RouteParser.parse(text)
        ▼
RouteInfo ─┬─▶ RouteHistory.add（解析成功時のみ履歴に保存）
           ├─▶ RouteResultView（解析結果カード + サービスボタン）
           │        ├─▶ EkinetWebViewPage ──JS注入──▶ えきねっと検索フォーム
           │        ├─▶ ExWebViewPage ──JS注入──▶ EX予約 Web版（ログイン→列車を検索→フォーム）
           │        └─▶ カレンダー登録（ACTION_INSERT）
           └─▶ 自動で開く（プレミアム時のみ）: 東海道・山陽・九州新幹線なら EX、それ以外はえきねっと
```

### 解析の要点（`lib/route_parser.dart`）

- 入力はプレーンテキスト。ヘッダー部（`東京⇒仙台` / `2026年08月28日` / `11:20 ⇒ 12:51`）と、`■駅名` と `↓` 行からなる区間ブロックを読む
- `---`、`★`、`(運賃内訳)`、URL 行以降は無視（フッター判定）
- 駅名末尾の括弧書き（`大宮(埼玉県)`、`羽田空港(空路)` など）は中身によらず全て除去。除去すると空になる場合は元のまま
- `RouteInfo.jrSegment` が予約サービスへ渡す区間を決める。優先順は「新幹線・特急を含む区間」→「JR の区間」→「経路全体」
- `RouteInfo.usesTokaidoSanyoKyushu` は列車名に「のぞみ・ひかり・こだま・みずほ・さくら・つばめ」を含むかで EX予約対象かを判定

### 状態管理

状態管理ライブラリは使っていません。`PremiumManager.instance.isPremium`（`ValueNotifier<bool>`）をシングルトンで持ち、`HomePage` と `SettingsPage` が購読しています。設定値は都度 `SharedPreferences` から読みます。

---

## 6. モジュール解説

| ファイル | 役割 | 引き継ぎ時の注意 |
|---|---|---|
| `lib/main.dart` | エントリポイント、`HomePage`（履歴一覧・共有受信・自動で開く）、履歴カード | 無料版の履歴表示は `PremiumManager.freeHistoryLimit`（3件）で切る |
| `lib/build_config.dart` | `kIsPlayStoreBuild` 定数（`--dart-define=PLAY_STORE=true`） | 出し分けの唯一のスイッチ。7章参照 |
| `lib/share_intent.dart` | MethodChannel `io.github.makiiii_git.y2eknt/share` の Dart 側 | チャンネル名は `MainActivity.kt` と一致させる |
| `lib/route_parser.dart` | 共有テキストの解析（`RouteParser`, `RouteInfo`, `TrainLeg`, `RouteSegment`） | Yahoo! 側のフォーマット変更に最も影響を受ける。テストが最も厚い |
| `lib/route_result_view.dart` | 解析結果カード、えきねっと／EX ボタン、カレンダー登録、テキストコピー | ボタンの優先順は EX対象経路かどうかで入れ替わる |
| `lib/route_history.dart` | 検索履歴（最大20件、原文を保存して表示時に再解析） | 同一テキストは重複させず先頭へ移動 |
| `lib/history_detail_page.dart` | 履歴の詳細画面（`RouteResultView` を再利用） | |
| `lib/ekinet.dart` | えきねっと検索ページ URL と自動入力 JS の生成 | フィールド ID は 2026-08-22 確認。8章参照 |
| `lib/ekinet_webview_page.dart` | えきねっとを WebView で開き、`onPageFinished` で一度だけ JS 注入 | URL に `RouteSearchConditionInput` を含むページのみ注入 |
| `lib/ex_webview_page.dart` | EX予約 Web版。自動ログイン→「列車を検索」クリック→フォーム入力の3段階 | フィールド name は 2026-08-23 確認。最も複雑で壊れやすい |
| `lib/ex_launcher.dart` | EX アプリ（`jp.co.jr_central.exreserve`）の App Link 起動と経路サマリーのコピー | 条件を渡す手段が無いためクリップボード補助のみ |
| `lib/ex_credentials.dart` | EX予約の会員ID・パスワードを `flutter_secure_storage` に保存 | 任意登録。外部送信なし |
| `lib/app_settings.dart` | EX連携 ON/OFF、自動で開く ON/OFF の永続化 | |
| `lib/settings_page.dart` | 設定画面（共有時の動作・プレミアム購入・EX連携・ログイン情報・バージョン・更新確認） | Play版／GitHub版で表示項目が変わる |
| `lib/premium.dart` | 買い切り課金 `premium_unlock` の購入・復元・状態キャッシュ | GitHub版は `init()` で即 `isPremium = true` |
| `lib/ad_banner.dart` | アンカー型アダプティブバナー（AdMob 本番ユニットID） | 無料版のホーム画面下部のみ |
| `lib/update_checker.dart` | GitHub Releases API から最新版と APK URL を取得、バージョン比較 | GitHub版のみ使用。arm64 APK を優先選択 |
| `android/.../MainActivity.kt` | `ACTION_SEND` を受け取り Dart へ渡す。`launchMode="singleTop"` | `onNewIntent` で起動中の共有にも対応 |

---

## 7. GitHub版とGoogle Play版の出し分け

出し分けはコンパイル時定数 `kIsPlayStoreBuild`（`lib/build_config.dart`）のみで行います。

| 機能 | GitHub版（フラグなし） | Play版（`PLAY_STORE=true`） | 理由 |
|---|---|---|---|
| バナー広告 | 表示しない | 無料版のみ表示 | AdMob は承認済みストア経由の配布が前提 |
| プレミアム課金 UI | 表示しない | 表示 | Play Billing が使えない |
| プレミアム機能（履歴無制限・自動で開く・EX連携） | 最初から全開放 | 購入で解放 | 課金できないため |
| 設定 → 更新を確認 | 表示 | 非表示 | Play 外からのアプリ更新は Play ポリシー違反 |
| 設定 → ソースコードリンク | 表示 | 非表示 | 同上（Play 外配布への誘導を避ける） |

Play版をビルドするときにフラグを付け忘れると、更新チェック付きの AAB が Play に上がります。9章のコマンドをそのまま使ってください。

---

## 8. 外部サイト依存（最も壊れやすい箇所）

このアプリの中核は、外部サイトの DOM に対する JavaScript 注入です。えきねっと・EX予約・Yahoo!乗換案内のいずれかが仕様変更すると動作しなくなります。**問い合わせが来たら、まずこの章の箇所を疑ってください。**

### 8.1 Yahoo!乗換案内の共有テキスト

- 想定フォーマットは `lib/route_parser.dart` 冒頭のコメントと `test/route_parser_test.dart` の実機サンプルを参照
- 2026-08 時点の実機サンプルに基づく。全角「ＪＲ」で JR 区間を判定している点に注意

### 8.2 えきねっと（`lib/ekinet.dart`）

| 項目 | 値 |
|---|---|
| 検索ページ | `https://www.eki-net.com/Personal/reserve/wb/RouteSearchConditionInput/Index` |
| 乗車駅 | `id=form_station_geton` |
| 降車駅 | `id=form_station_getoff` |
| 日付 | `name=form_date_oneway_date`（値は `YYYYMMDD`） |
| 時 / 分 | `name=form_date_oneway_hour` / `name=form_date_oneway_minute`（分は5分単位に切り捨て） |
| 出発指定ラジオ | `id=form_date_oneway_Dep` |
| 確認日 | 2026-08-22 |

GET パラメータ付き遷移 URL は存在しない（POST + CSRF トークン方式）ため WebView + JS 注入方式を採っています。

### 8.3 EX予約 Web版（`lib/ex_webview_page.dart`）

| 項目 | 値 |
|---|---|
| 起動 URL（ログイン情報なし） | `https://expy.jp/login/` |
| 起動 URL（ログイン情報あり） | `https://shinkansen1.jr-central.co.jp/RSV_P/S_index.htm` |
| ログインフォーム | ID `name=01`、パスワード `name=02`、送信ボタン `name=05` |
| メニュー | テキストが「列車を検索」の要素をクリック |
| 乗車駅 / 降車駅 | `select name=s6` / `select name=s7`（option のテキストと駅名を照合） |
| 時 / 分 / 出発到着 | `name=02`（06〜23）/ `name=03`（5分刻み）/ `name=04`（1=出発） |
| 日付 | カレンダーの `class="YYYYMMDD selectable"` セルをクリック。無ければ `date_click(ymd, 表示文字列)` を呼ぶ |
| 確認日 | 2026-08-23 |

処理は `_tryAutoLogin` → `_tryOpenSearchMenu` → `_tryAutofill` の順で、各ステップは URL パターンと DOM の有無で「対象外なら何もしない」安全側に倒しています。SMS 認証などの追加ステップはユーザー操作に委ねます。

### 8.4 EX アプリ（`lib/ex_launcher.dart`）

`https://shinkansen1.jr-central.co.jp/RSV_P/ex_index.htm` が EX アプリの App Link になっている（2026-08 実機調査）ことを利用しています。アプリ側に条件を渡せないため、経路サマリーをクリップボードにコピーして起動するだけです。

### 8.5 GitHub API（`lib/update_checker.dart`）

`https://api.github.com/repos/makiiii-git/Y2Eknt/releases/latest` を認証なしで呼びます。未認証のレート制限（IP あたり毎時60回）の範囲内です。

---

## 9. ビルド・リリース手順

### 9.1 バージョン番号の付け方

- `pubspec.yaml` の `version: X.Y.Z+N` を編集する。`X.Y.Z` が versionName、`N` が versionCode
- **N は必ず前回より大きくする**（Play・APK 上書き更新の両方で必須）
- GitHub版 APK は `--split-per-abi` により versionCode が `N + 2000` になる（arm64 のオフセット）。現行リリースは 2015。**`--split-per-abi` を外すと versionCode が 2000 台を下回り、既存ユーザーが上書き更新できなくなる**ため、外してはいけない
- Play版 AAB は素の `N` を使う。GitHub版と Play版は署名鍵も別なので相互に上書きはできない

### 9.2 GitHub Releases（APK）

1. `pubspec.yaml` の version を上げてコミット
2. `main` にプッシュ（この時点で CI が analyze / test / ビルドを実行し、Artifact として APK を保存）
3. タグを打つ。**タグ名は大文字 `V` + バージョン**（例 `V1.0.5`）。ワークフローの `tags: ['V*.*.*']` と `if: startsWith(github.ref, 'refs/tags/V')` が大文字 `V` 前提

   ```bash
   git tag V1.0.5
   git push origin V1.0.5
   ```

4. CI が `Y2Eknt-v1.0.5.apk`（小文字 `v`）を Releases にアップロードする
5. Actions ログの「Show signer fingerprint」で SHA-256 が前回と同じことを確認する。違っていたら鍵が変わっており、既存ユーザーが更新できない

ローカルで同じ APK を作る場合:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64
# 出力: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### 9.3 Google Play（AAB）

```bash
flutter build appbundle --release --dart-define=PLAY_STORE=true
# 出力: build/app/outputs/bundle/release/app-release.aab
```

- `android/key.properties` と keystore（`.jks`）をローカルに置く。両方とも `.gitignore` 済みでリポジトリには含まれない
- `key.properties` の形式は CI ワークフローの `Set up release signing` ステップに書かれているとおり（`storeFile` / `storePassword` / `keyAlias` / `keyPassword`）
- `key.properties` が無い環境ではデバッグ署名にフォールバックする（`android/app/build.gradle.kts`）。Play にはアップロードできないので気付ける
- AAB は Play Console に手動でアップロードする。CI は AAB を作らない

### 9.4 CI（`.github/workflows/build_apk.yml`）

| トリガー | 動作 |
|---|---|
| `main` への push | analyze → test → arm64 APK ビルド → Artifact 保存 |
| タグ `V*.*.*` の push | 上記に加え GitHub Releases へアップロード |
| 手動（workflow_dispatch） | Artifact 保存まで |

必要な Repository Secrets（未設定だと警告付きでデバッグ署名になる）:

| Secret | 内容 |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | GitHub配布用 keystore を base64 化したもの |
| `RELEASE_STORE_PASSWORD` | keystore のパスワード |
| `RELEASE_KEY_PASSWORD` | 鍵のパスワード |
| `RELEASE_KEY_ALIAS` | 鍵のエイリアス |

**この GitHub配布用鍵と Play アップロード鍵は別物の可能性があります。** どちらも前任者から安全な経路で受け取り、紛失しないようにしてください。鍵を失うと既存ユーザーは新バージョンへ上書き更新できなくなります。

### 9.5 アイコンの再生成

```bash
dart run flutter_launcher_icons
```

元画像は `assets/icon/icon.png`（通常）と `assets/icon/icon_fg.png`（アダプティブ前景）。背景色は `#00A044`。

---

## 10. Google Play 関連

| 項目 | 値 | 場所 |
|---|---|---|
| パッケージ名 | `io.github.makiiii_git.y2eknt` | `android/app/build.gradle.kts` |
| アプリ内アイテム ID | `premium_unlock`（買い切り・非消費型） | `lib/premium.dart`。Play Console に同じ ID で登録が必要 |
| 想定価格 | 100円 | `closed-test-recruit.md` の記載。Play Console 側の設定値を確認すること |
| AdMob アプリ ID | `ca-app-pub-5796626901181447~3379727368` | `AndroidManifest.xml` |
| AdMob バナーユニット ID | `ca-app-pub-5796626901181447/8168135134` | `lib/ad_banner.dart` |
| targetSdk | 36（2026-08-31 以降の必須要件に対応済み） | `android/app/build.gradle.kts` |
| Billing Library | 8（`in_app_purchase_android` 0.5.x 経由） | Billing 7 は 2026-08-31 にサポート終了 |
| プライバシーポリシー URL | https://makiiii-git.github.io/Y2Eknt/privacy-policy.html | Play Console のストア設定に登録 |
| 掲載文 | `store-listing.md` | アプリ名 25文字 / 簡単な説明 67文字 |
| 掲載画像 | `store-assets/`（512px アイコン、1024×500 フィーチャーグラフィック、スクリーンショット2枚） | |

### プレミアム機能の一覧

| 機能 | 無料版（Play） | プレミアム（Play） | GitHub版 |
|---|---|---|---|
| バナー広告 | 表示 | 非表示 | 非表示 |
| 検索履歴の表示 | 3件まで | 無制限（保存は最大20件） | 無制限 |
| 自動で開く | 不可 | 可 | 可 |
| EX予約連携（Web版） | 不可 | 可 | 可 |

購入状態の正は Play Billing です。`SharedPreferences` の `premium_unlocked` は起動直後の表示用キャッシュで、起動時の `restorePurchases()` と `purchaseStream` で同期します。

### クローズドテストの進め方

`closed-test-recruit.md` の「投稿前に用意するもの」表が手順書を兼ねています（Googleグループ作成 → クローズドテストトラック作成 → テスターにグループ指定 → AAB アップロード → オプトイン URL 取得）。個人アカウントでは 12人以上・14日間継続が製品版公開の条件のため、15〜20人を目安に集めることが推奨されています。

---

## 11. テスト

```bash
flutter test
```

| ファイル | 対象 | 主な観点 |
|---|---|---|
| `test/route_parser_test.dart` | `RouteParser` / `RouteInfo` | 実機サンプルの解析、乗換あり経路、JR区間抽出、括弧書き除去、失敗時のフォールバック |
| `test/ekinet_test.dart` | `Ekinet.buildAutofillScript` | 生成 JS に駅名・日付・時刻が含まれるか、5分切り捨て、エスケープ |
| `test/update_checker_test.dart` | `UpdateChecker` | バージョン比較、タグ接頭辞除去、ABI別 APK が並んでも arm64 を選ぶ（未リリースの修正に対応） |
| `test/route_history_test.dart` | `RouteHistory` | 新しい順、重複排除、上限20件、削除、壊れたデータ |
| `test/app_settings_test.dart` | `AppSettings` | 既定値と保存 |
| `test/widget_test.dart` | ビルド構成 | GitHub版（フラグなし）で課金・広告が無効であること |

WebView への JS 注入と課金・広告は自動テストで検証できません。**えきねっと・EX予約の自動入力は実機（または実機相当のエミュレータ）で手動確認してください。** 確認用テキストは `closed-test-recruit.md` の「動作確認のしかた」にあります（Yahoo!乗換案内が無くてもメモ帳などから共有すれば試せます）。

---

## 12. 端末内に保存するデータ

| 保存先 | キー | 内容 |
|---|---|---|
| SharedPreferences | `ex_integration_enabled` | EX予約連携 ON/OFF（既定 false） |
| SharedPreferences | `auto_open_ekinet` | 自動で開く ON/OFF（既定 false） |
| SharedPreferences | `route_history` | 検索履歴（JSON 配列、最大20件） |
| SharedPreferences | `premium_unlocked` | プレミアム状態のキャッシュ |
| flutter_secure_storage | `ex_member_id` / `ex_password` | EX予約ログイン情報（任意登録、Android Keystore で暗号化） |
| WebView Cookie | （システム管理） | えきねっと・EX予約のログインセッション |

いずれも端末内のみで、開発者側への送信はありません。キー名を変えると既存ユーザーの設定・履歴が消えるので注意してください。

---

## 13. 既知の課題・注意点・TODO

### すぐに対応が必要なもの

1. **未リリースの更新チェック修正を配布する。** `main` @ `4a516c1` の修正（8章 8.5、2章参照）は V1.0.4 に含まれていない。version を `1.0.5+16` に上げて `V1.0.5` タグを打つ
2. **Play Console の現状確認。** 内部テスト／クローズドテスト／製品版のどの段階か、`premium_unlock` の登録と価格、AdMob アプリの審査状態をリポジトリからは確認できない

### 設計上の制約・割り切り

- **外部サイト依存**（8章）。定期的に実機で動作確認し、壊れたら該当セレクタを更新する運用が必要
- EX アプリへ条件を渡す手段が無く、クリップボード補助にとどまる
- えきねっとのメンテナンス時間帯（おおむね深夜〜早朝）は検索できない
- 駅名の照合は文字列一致。Yahoo! とえきねっと／EX で表記が異なる駅（例: 括弧書き付き）は `normalizeStation` で吸収しているが、網羅はしていない
- EX予約の自動ログインは `flutter_secure_storage` に平文パスワードを暗号化保存する方式。ユーザーの任意登録であることをプライバシーポリシーと設定画面で明示している
- 履歴は原文をそのまま保存し表示時に再解析するため、パーサー改善が過去の履歴にも効く（逆にパーサー退行も履歴表示に影響する）

### コード上の小さな残課題

- `android/app/build.gradle.kts` のコメントに「Flutter 3.29.3 の既定は35」とあるが、現在は Flutter 3.38.10 を使用。コメントのみ古い
- `android/app/build.gradle.kts` に Flutter テンプレート由来の `TODO: Specify your own unique Application ID` コメントが残っているが、Application ID 自体は設定済み
- `.metadata` の `channel: "[user-branch]"` は開発機の Flutter がカスタムブランチだったことを示す。CI は stable 3.38.10 で動作確認済み
- `analysis_options.yaml` は既定のまま。追加の lint ルールは無い

### 今後の改善候補（未着手）

- 復路・往復検索への対応（現在は片道のみ）
- 複数の乗換アプリ（Google マップ、NAVITIME など）の共有フォーマット対応
- Play版の AAB ビルドを CI で自動化（現在は手動）
- Issue テンプレート・PR テンプレートの整備（現状なし）

---

## 14. 引き継ぎに必要なアカウント・秘密情報チェックリスト

値はこの資料に書かず、前任者から安全な経路で受け取ってください。

| 項目 | 用途 | 確認 |
|---|---|---|
| GitHub リポジトリ `makiiii-git/Y2Eknt` の管理者権限 | コード・Releases・Actions Secrets・Pages の管理 | ☐ |
| GitHub Actions Secrets 4種（9.4章） | GitHub配布 APK の署名 | ☐ |
| GitHub配布用 keystore ファイルとパスワード | 上記 Secrets の元。ローカルビルド時にも使用 | ☐ |
| Play アップロード用 keystore と `key.properties` | AAB の署名 | ☐ |
| Google Play Console のアカウント（アプリ `io.github.makiiii_git.y2eknt`） | 公開・テスト・課金設定 | ☐ |
| AdMob アカウント（アプリ ID `ca-app-pub-5796626901181447~…`） | 広告配信・収益 | ☐ |
| クローズドテスト用 Googleグループ（作成済みなら） | テスター管理 | ☐ |
| 問い合わせ用メールアドレス | テスター募集文に記載の連絡先（`makitaforai2@gmail.com`） | ☐ |
| EX予約・えきねっとのテスト用アカウント | 自動入力の実機確認 | ☐ |

---

## 15. 用語集

| 用語 | 意味 |
|---|---|
| えきねっと | JR東日本の新幹線・特急予約サイト。主に東日本・北陸・北海道方面 |
| EX予約 / スマートEX | JR東海・JR西日本・JR九州の東海道・山陽・九州新幹線予約サービス。本アプリは Web版（`expy.jp` / `shinkansen1.jr-central.co.jp`）と EX アプリの両方に対応 |
| JR区間 | 経路のうち地下鉄・私鉄・在来線アクセスを除いた、予約サービスへ渡す区間（`RouteInfo.jrSegment`） |
| 東海道・山陽・九州新幹線経路 | 列車名にのぞみ・ひかり・こだま・みずほ・さくら・つばめを含む経路。EX予約の対象 |
| GitHub版 / Play版 | 配布経路によるビルド種別（7章） |
| プレミアム | Play版の買い切り課金 `premium_unlock` で解放される機能群 |
| 自動で開く | 共有受信後にボタンを押さず予約サービスへ遷移する設定 |
| ABI | CPU アーキテクチャ種別。GitHub版は arm64-v8a のみ配布 |
