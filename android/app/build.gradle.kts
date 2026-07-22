plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Must be applied AFTER com.android.application — reads
    // google-services.json (this file must exist at android/app/) and
    // wires the project_id/api_key it needs into the build.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.doon_walkers"
    compileSdk = flutter.compileSdkVersion
    // Pinned to NDK 27 — required by supabase_flutter's transitive plugins
    // (app_links, path_provider_android, shared_preferences_android, url_launcher_android).
    // NDK versions are backward-compatible; this is safe to raise.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.doon_walkers"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 23, not flutter.minSdkVersion (21) — firebase_messaging's current
        // Android implementation requires API 23+; building below that
        // fails at compile time with a manifest merger/dependency error.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
