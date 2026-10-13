import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Console アップロード用の署名情報（gitには含めない）。
// android/key.properties が無い環境（CI等）ではデバッグ署名にフォールバックする。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "io.github.makiiii_git.y2eknt"
    // Google Play の対象APIレベル要件（2026年8月31日以降はAPI 36が必須）。
    // Flutter 3.29.3 の既定は35のため明示的に上書きする。
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.makiiii_git.y2eknt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage（Android Keystore暗号化）の要件
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 共有先一覧で Play 版と区別できるようアプリ名をビルド種別ごとに変える
        manifestPlaceholders["appLabel"] = "Y2Eknt"
        // AdMobアプリID（本番）
        manifestPlaceholders["admobAppId"] = "ca-app-pub-5796626901181447~3379727368"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Google提供のテスト用AdMobアプリID
    val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"

    buildTypes {
        // デバッグ版はアプリIDを変えて、Play版がインストール済みの端末にも
        // アンインストールせずに並行インストールできるようにする
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "Y2Eknt Debug"
            // 開発用ビルドから本番のAdMobアプリIDを使うと未登録アプリとして検出されるため
            manifestPlaceholders["admobAppId"] = admobTestAppId
        }
        release {
            // リリース版の実機確認用（Play版と並行インストールする）:
            //   flutter build apk --release --android-project-arg=r8test=true
            if (project.hasProperty("r8test")) {
                applicationIdSuffix = ".r8test"
                manifestPlaceholders["admobAppId"] = admobTestAppId
            }
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Kotlin 2.2 で kotlinOptions は廃止されたため compilerOptions で指定する
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
